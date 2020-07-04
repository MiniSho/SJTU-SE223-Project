use HospitalAppointment;

drop function if exists check_open_by_policy;
drop function if exists check_doctor_available;
drop procedure if exists 专家预约;
drop procedure if exists 普通预约;
drop function if exists convert_dayofweek_to_friendly_repr;
drop function if exists convert_gender_to_friendly_repr;
drop procedure if exists 病人_查询接诊安排;

delimiter $$

-- 检查传入的接诊安排在考虑未执行的事件后是否开放。
create function check_open_by_policy(_科室编号 int, _时段编号 int, _医生编号 int, _日期 date)
    returns boolean deterministic
begin
    declare latest_policy int default null;
    declare latest_policy_date date default null;
    -- 执行政策检查，这是为了检测是否存在当前尚未执行但在预约时间之前发生的事件。
    -- 预约日期不是当天，因此可能存在目前暂未执行的事件。
    select `政策`, `日期`
    into latest_policy,latest_policy_date
    from `事件`
    where `医生编号` = _医生编号
      and `科室编号` = _科室编号
      and `时段编号` = _时段编号
      and `日期` <= _日期
    order by `日期` desc
    limit 1;
    -- 若预约日期在该时段该医生的最新已计划的永久关闭的日期之后，则拒绝预约
    -- 若预约日期当天有临时关闭该医生该时段门诊的计划，则拒绝预约。
    -- 若预约日期在该时段该医生的最新已计划重新开放日期之后，则允许预约
    if latest_policy is not null then
        if latest_policy = 1 or (latest_policy = 2 and curdate() = latest_policy_date) then
            return false;
        else
            return true;
        end if;
    end if;

    -- 若没有未执行的事件，则由门诊开放属性决定。
    return (select `门诊开放`
            from `医生接诊安排`
            where `医生编号` = _医生编号
              and `科室编号` = _科室编号
              and `时段编号` = _时段编号);
end $$

-- 事件功能辅助函数，简化其他代码中的检查逻辑。
-- 返回true即表示所查询的医生在所查询的时段与日期可以接诊。
create function check_doctor_available(_科室编号 int, _时段编号 int, _医生编号 int, _日期 date)
    returns boolean deterministic
begin
    declare plan_limit int;
    if check_open_by_policy(_科室编号, _时段编号, _医生编号, _日期) = false then
        return false;
    end if;

    select `接诊人数上限`
    into plan_limit
    from `医生接诊安排`
    where `医生编号` = _医生编号
      and `科室编号` = _科室编号
      and `时段编号` = _时段编号;

    return (select count(*)
            from `预约`
            where `是否就诊` = 0
              and `预约`.`医生编号` = _医生编号
              and `预约`.`科室编号` = _科室编号
              and `预约`.`时段编号` = _时段编号
              and `预约`.`预约日期` = _日期
           ) < plan_limit;
end $$

-- 专家预约：病人可以指定某个医生的某个时段进行预约，仅受到由trigger保证的预约限制。
create procedure 专家预约(in _病人编号 int, in _科室编号 int, in _时段编号 int, in _医生编号 int, in _日期 date) not deterministic
begin
    insert into `预约`(病人编号, 医生编号, 科室编号, 时段编号, 预约日期, 是否就诊, 评分, 挂号类别) value (_病人编号, _医生编号, _科室编号, _时段编号, _日期, 0, null, 1);
end $$

-- 普通预约：病人指定某个科室及时段，由系统随机分配一位在所选时段接诊且在所选日期尚未预约满的医生
-- 如果没有找到满足要求的医生，则引发异常
create procedure 普通预约(in _病人编号 int, in _科室编号 int, in _时段编号 int, in _日期 date) not deterministic
begin
    declare 分配医生编号 int default null;
    set 分配医生编号 = (select `医生编号`
                  from `医生接诊安排`
                  where `科室编号` = _科室编号
                    and `时段编号` = _时段编号
                    -- 检查医生在当天当时段是否已经约满
                    and check_doctor_available(_科室编号, _时段编号, `医生编号`, _日期)
                    -- rand函数为每个tuple生成一个随机数，以其排序并取第一个tuple等价于随机挑选一个tuple
                  order by rand()
                  limit 1);
    if (分配医生编号 is null) then
        signal sqlstate '45000' set message_text = '您选择的时段没有可预约的医生！';
    end if;
    insert into `预约`(病人编号, 医生编号, 科室编号, 时段编号, 预约日期, 是否就诊, 评分, 挂号类别) value (_病人编号, 分配医生编号, _科室编号, _时段编号, _日期, 0, null, 2);
end $$

-- 将使用数值表示的星期转换为对人易读的形式
-- 数值值遵循MySQL dayofweek返回值的标准。
create function convert_dayofweek_to_friendly_repr(dayofweek int) returns varchar(10) deterministic
begin
    return (case
                when dayofweek = 1 then '星期日'
                when dayofweek = 2 then '星期一'
                when dayofweek = 3 then '星期二'
                when dayofweek = 4 then '星期三'
                when dayofweek = 5 then '星期四'
                when dayofweek = 6 then '星期五'
                when dayofweek = 7 then '星期六'
        end);
end $$

-- 将使用数值表示的性别转为对人易读的形式
create function convert_gender_to_friendly_repr(gender int) returns varchar(2) deterministic
begin
    return (case
                when gender = 1 then '男'
                when gender = 2 then '女'
        end);
end $$

-- 列出病人所需的综合信息
-- 过程将扫描[_开始日期,_结束日期]中每一天在[_每日开始钟点,_每日结束钟点]间的所有医生接诊安排的相关数据
-- 需要日期以检测是否可预约。
-- 在JetBrains DataGrip上执行存在问题，因该procedure返回多结果集，而结果集需传输至JVM内存中，
-- DataGrip似乎不支持多结果集在一个过程中一次性产生。
create procedure 病人_查询接诊安排(_开始日期 date, _结束日期 date, _每日开始钟点 time, _每日结束钟点 time) deterministic
begin
    declare cur_date date default _开始日期;
    if (curdate() >= _开始日期) then
        signal sqlstate '45000' set message_text = '您只能预约未来一天及以后的时段！';
    end if;
    -- 使用循环迭代cur_date，每次递增一天，直到统计完结束日期的数据
    search_by_date:
    loop
        if (cur_date > _结束日期) then
            leave search_by_date;
        end if;
        select cur_date                                                 as `日期`,
               convert_dayofweek_to_friendly_repr(dayofweek(cur_date))  as `星期`,
               check_doctor_available(`科室编号`, `时段编号`, `医生编号`, cur_date) as `是否可预约`,
               `医生编号`,
               `姓名`                                                     as `医生姓名`,
               convert_gender_to_friendly_repr(`性别`)                    as `性别`,
               `联系方式`,
               `专业`,
               `职称`,
               `科室编号`,
               `科室`.`名称`                                                as `科室名称`,
               `时段编号`,
               `开始钟点`,
               `结束钟点`,
               (select count(*)
                from `预约`
                where `预约日期` = cur_date
                  and `医生编号` = `医生接诊安排`.`医生编号`
                  and `科室编号` = `医生接诊安排`.`科室编号`
                  and `时段编号` = `时段`.`时段编号`
               )                                                        as `当天该时段已预约人数`,
               `接诊人数上限`
        from `用户`
                 natural join `角色分配`
                 natural join `医生资料`
                 natural join `医生接诊安排`
                 join `科室` using (`科室编号`)
                 natural join `时段`
        where `时段`.`星期` = dayofweek(cur_date)
          and `时段`.`开始钟点` >= _每日开始钟点
          and `时段`.`结束钟点` <= _每日结束钟点;
        set cur_date = date_add(cur_date, interval 1 day);
    end loop;
end $$