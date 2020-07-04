use HospitalAppointment;

drop event if exists ExecutePolicy;
drop event if exists ClearOverdueAppointment;

delimiter $$

create event ExecutePolicy
    on schedule
        every '1 2' day_hour do
    begin
        declare process_finish boolean default false;
        declare doctor_id int;
        declare dept_id int;
        declare interval_id int;
        declare policy int;
        declare today_event cursor for (select `医生编号`, `科室编号`, `时段编号`, `政策`
                                        from HospitalAppointment.`事件`
                                        where `日期` = curdate());
        declare continue handler for not found set process_finish = true;
        open today_event;
        fetch today_event into doctor_id,dept_id,interval_id,policy;
        policy_loop:
        loop
            if process_finish then
                leave policy_loop;
            end if;
            -- 规定政策取1为定时永久关闭，取3为定时重新开放。
            update HospitalAppointment.`医生接诊安排`
            set `门诊开放`=(case
                            when policy = 1 then 0
                            when policy = 3 then 1
                end)
            where `医生编号` = doctor_id
              and `科室编号` = dept_id
              and `时段编号` = interval_id;
            -- 事件执行完成后，清除该事件以减少冗余数据。。
            delete
            from HospitalAppointment.`事件`
            where `医生编号` = doctor_id
              and `科室编号` = dept_id
              and `时段编号` = interval_id
              and `日期` = curdate();
        end loop;
    end $$

-- 定时删除所有已逾期预约
-- 逾期定义：在预约次日就诊状态仍为false
create event ClearOverdueAppointment on schedule every '1 2' day_hour do
    begin
        delete from HospitalAppointment.`预约` where `预约日期` < curdate() and `是否就诊` = 0;
    end $$

delimiter ;