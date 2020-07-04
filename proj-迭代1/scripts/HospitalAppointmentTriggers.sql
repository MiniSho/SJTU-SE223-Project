use HospitalAppointment;

drop trigger if exists EnsureRoleAndProfileConsistency;
drop trigger if exists EnsureRollbackIllegalTime;
drop trigger if exists EnsureAppointmentLimit;
drop trigger if exists EnsureDepartmentArrangeNoConflict;
drop trigger if exists EnsureDoctorAttendItsDepartment;
drop trigger if exists EnsureLegalPolicy;

delimiter $$

-- 确保每个时段的开始钟点大于结束钟点
-- 有没有考虑跨天如晚上到凌晨的时段？本系统为预约系统，而那样的时段一般是急诊，而非事先预约的时段
-- 因此要求结束钟点大于开始钟点是符合业务需求的
create trigger EnsureRollbackIllegalTime
    before insert
    on `时段`
    for each row
begin
    if NEW.开始钟点 >= NEW.结束钟点 then
        -- 使用signal引发异常，进而导致触发trigger的transaction rollback
        -- 不可直接rollback，因为trigger自身亦处于单独transaction之中
        signal sqlstate '45000' set message_text = '结束钟点应大于开始钟点！';
    end if;
end $$

-- 确保不会为同一个科室分配两个互相重叠的时段
create trigger EnsureDepartmentArrangeNoConflict
    before insert
    on `科室接诊计划`
    for each row
begin
    declare new_time_weekn int;
    declare new_time_start time;
    declare new_time_end time;
    -- 获取所分配时段的信息
    select `星期`, `开始钟点`, `结束钟点` into new_time_weekn,new_time_start,new_time_end from `时段` where `时段编号` = NEW.`时段编号`;
    if exists(select *
              from `科室接诊计划`
                       natural join `时段` -- 查找该科室当天（星期几）已有的时段
              where NEW.`科室编号` = `科室编号`
                and new_time_weekn = `星期`
                -- 设新分配区间[a,b]，已有区间[c,d]，若：
                -- a<=c<=b 或 a<=d<=b (两个区间有交叉）
                -- 或 c<=a<b<=d ([a,b]为[c,d]的子区间）
                -- 则二者冲突。
                and (((`开始钟点` between new_time_start and new_time_end) or
                      (`结束钟点` between new_time_start and new_time_end))
                  or (new_time_start >= `开始钟点` and new_time_end <= `结束钟点`))) then
        signal sqlstate '45000' set message_text = '试图分配与该科室已有时段冲突的时段';
    end if;
end $$

-- 确保为用户分配某个角色时，也必须一并分配相应的未被分配给其他用户的角色资料
create trigger EnsureRoleAndProfileConsistency
    before insert
    on `角色分配`
    for each row
begin
    if NEW.`名称` = '病人' and NEW.`病人编号` is null then
        signal sqlstate '45000' set message_text = '分配病人角色必须指定病人编号';
    elseif NEW.`名称` = '医生' and NEW.`医生编号` is null then
        signal sqlstate '45000' set message_text = '分配医生角色必须指定医生编号';
    elseif NEW.`名称` = '管理员' and NEW.`管理员编号` is null then
        signal sqlstate '45000' set message_text = '分配管理员角色必须指定管理员编号';
    end if;
    -- 检测所分配的角色资料是否已被分配给其他用户
    if NEW.`名称` = '病人' then
        if (NEW.`病人编号` in (select `病人编号` from `角色分配`)) then
            signal sqlstate '45000' set message_text = '病人资料已分配给其他用户';
        end if;
    elseif NEW.`名称` = '医生' then
        if (NEW.`医生编号` in (select `医生编号` from `角色分配`)) then
            signal sqlstate '45000' set message_text = '医生资料已分配给其他用户';
        end if;
    elseif NEW.`名称` = '管理员' then
        if (NEW.`管理员编号` in (select `管理员编号` from `角色分配`)) then
            signal sqlstate '45000' set message_text = '管理员资料已分配给其他用户';
        end if;
    end if;
end $$

-- 确保医生只能被分配至其所属科室的某个计划时段接诊
create trigger EnsureDoctorAttendItsDepartment
    before insert
    on `医生接诊安排`
    for each row
begin
    if (NEW.`医生编号` not in (select `医生编号` from `科室分配` where `科室编号` = NEW.`科室编号`)) then
        signal sqlstate '45000' set message_text = '医生只能被安排至其所属科室接诊';
    end if;
end $$

-- 为新增的预约施加以下限制：
-- 不能预约已有事件指定关闭的时段
-- 不能预约门诊未开放的时段
-- 不能预约当天预约已满的时段
-- 不能预约所选择日期与星期不一致（即所选的时段不在所选的日期执行）的时段
-- 必须预约距当天一天及以后的时段
create trigger EnsureAppointmentLimit
    before insert
    on `预约`
    for each row
begin
    declare plan_limit int;
    if not check_open_by_policy(NEW.`科室编号`, NEW.`时段编号`, NEW.`医生编号`, NEW.`预约日期`) then
        signal sqlstate '45000' set message_text = '您预约的医生当天该时段门诊暂未开放！';
    end if;
    -- 统计所有已预约了该接诊安排，且尚未就诊，且日期与新预约日期相同的预约数量，
    -- 如果已经等于plan_limit，说明当天该医生在该时段已经预约满了，则拒绝新的预约。
    -- 未使用已定义函数，因为需要有不同的提示消息。
    select `接诊人数上限`
    into plan_limit
    from `医生接诊安排`
    where `医生编号` = NEW.`医生编号`
      and `科室编号` = NEW.`科室编号`
      and `时段编号` = NEW.`时段编号`;
    if (select count(*)
        from `预约`
        where `是否就诊` = 0
          and `医生编号` = NEW.`医生编号`
          and `科室编号` = NEW.`科室编号`
          and `时段编号` = NEW.`时段编号`
          and `预约日期` = NEW.`预约日期`
       ) = plan_limit then
        signal sqlstate '45000' set message_text = '您预约的医生当天该时段预约人数已满！';
    end if;
    -- 使用dayofweek计算日期所对应的星期，注意dayofweek返回为1-7,依次为周日-周六。
    if (dayofweek(NEW.`预约日期`) <> (select `星期` from `时段` where `时段编号` = NEW.`时段编号`)) then
        signal sqlstate '45000' set message_text = '您选择的时段不在您的预约日期！';
    end if;
    if (curdate() >= NEW.`预约日期`) then
        signal sqlstate '45000' set message_text = '您只能预约未来一天及以后的时段！';
    end if;
end $$

-- 确保每条事件均指定合法政策
-- 规定政策值为1表示计划永久关闭接诊，政策值为2表示当日临时关闭接诊，政策值为3计划重新开放.
create trigger EnsureLegalPolicy
    before insert
    on `事件`
    for each row
begin
    if NEW.`政策` not in (1, 2, 3) then
        signal sqlstate '45000' set message_text = '不合法的政策类型！';
    end if;
end $$
