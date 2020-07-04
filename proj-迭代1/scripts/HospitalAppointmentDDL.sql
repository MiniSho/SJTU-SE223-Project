create database HospitalAppointment;
use HospitalAppointment;

-- ****************** SqlDBM: MySQL ******************;
-- ***************************************************;


-- ************************************** `用户`

CREATE TABLE `用户`
(
    `ID`   int         NOT NULL auto_increment,
    `用户名`  varchar(40) NOT NULL,
    `密码`   varchar(64) NOT NULL,
    `姓名`   varchar(40) NOT NULL,
    `性别`   int         NOT NULL,
    `联系方式` varchar(20) NOT NULL,

    PRIMARY KEY (`ID`)
);

-- ****************** SqlDBM: MySQL ******************;
-- ***************************************************;


-- ************************************** `角色`

CREATE TABLE `角色`
(
    `名称` varchar(40) NOT NULL,

    PRIMARY KEY (`名称`)
);

-- ****************** SqlDBM: MySQL ******************;
-- ***************************************************;


-- ************************************** `病人资料`

CREATE TABLE `病人资料`
(
    `病人编号`   int          NOT NULL auto_increment,
    `家庭住址`   varchar(100) NOT NULL,
    `紧急联系方式` varchar(20)  NOT NULL,
    `过往病史`   text         NOT NULL,
    `出生年月`   date     NOT NULL,

    PRIMARY KEY (`病人编号`)
);

-- ****************** SqlDBM: MySQL ******************;
-- ***************************************************;


-- ************************************** `医生资料`

CREATE TABLE `医生资料`
(
    `医生编号` int          NOT NULL auto_increment,
    `专业`   varchar(100) NOT NULL,
    `职称`   varchar(100) NOT NULL,

    PRIMARY KEY (`医生编号`)
);

-- ****************** SqlDBM: MySQL ******************;
-- ***************************************************;


-- ************************************** `管理员资料`

CREATE TABLE `管理员资料`
(
    `管理员编号` int          NOT NULL auto_increment,
    `职务`    varchar(100) NOT NULL,

    PRIMARY KEY (`管理员编号`)
);

-- ****************** SqlDBM: MySQL ******************;
-- ***************************************************;


-- ************************************** `角色分配`

CREATE TABLE `角色分配`
(
    `ID`    int         NOT NULL,
    `名称`    varchar(40) NOT NULL,
    `病人编号`  int         NULL,
    `医生编号`  int         NULL,
    `管理员编号` int         NULL,

    PRIMARY KEY (`ID`, `名称`),
    KEY `fkIdx_151` (`管理员编号`),
    CONSTRAINT `FK_151` FOREIGN KEY `fkIdx_151` (`管理员编号`) REFERENCES `管理员资料` (`管理员编号`),
    KEY `fkIdx_48` (`病人编号`),
    CONSTRAINT `FK_48` FOREIGN KEY `fkIdx_48` (`病人编号`) REFERENCES `病人资料` (`病人编号`),
    KEY `fkIdx_51` (`医生编号`),
    CONSTRAINT `FK_51` FOREIGN KEY `fkIdx_51` (`医生编号`) REFERENCES `医生资料` (`医生编号`),
    KEY `fkIdx_54` (`ID`),
    CONSTRAINT `FK_54` FOREIGN KEY `fkIdx_54` (`ID`) REFERENCES `用户` (`ID`),
    KEY `fkIdx_57` (`名称`),
    CONSTRAINT `FK_57` FOREIGN KEY `fkIdx_57` (`名称`) REFERENCES `角色` (`名称`)
);


-- ****************** SqlDBM: MySQL ******************;
-- ***************************************************;


-- ************************************** `科室`

CREATE TABLE `科室`
(
    `科室编号` int         NOT NULL auto_increment,
    `名称`   varchar(40) NOT NULL,

    PRIMARY KEY (`科室编号`)
);

-- ****************** SqlDBM: MySQL ******************;
-- ***************************************************;


-- ************************************** `时段`

CREATE TABLE `时段`
(
    `时段编号` int  NOT NULL auto_increment,
    `开始钟点` time NOT NULL,
    `结束钟点` time NOT NULL,
    `星期`   int  NOT NULL,

    PRIMARY KEY (`时段编号`)
);

-- ****************** SqlDBM: MySQL ******************;
-- ***************************************************;


-- ************************************** `科室分配`

CREATE TABLE `科室分配`
(
    `医生编号` int NOT NULL,
    `科室编号` int NOT NULL,

    primary key (`医生编号`, `科室编号`),
    KEY `fkIdx_69` (`医生编号`),
    CONSTRAINT `FK_69` FOREIGN KEY `fkIdx_69` (`医生编号`) REFERENCES `医生资料` (`医生编号`),
    KEY `fkIdx_75` (`科室编号`),
    CONSTRAINT `FK_75` FOREIGN KEY `fkIdx_75` (`科室编号`) REFERENCES `科室` (`科室编号`)
);

-- ****************** SqlDBM: MySQL ******************;
-- ***************************************************;


-- ************************************** `科室时段`


CREATE TABLE `科室接诊计划`
(
    `科室编号` int NOT NULL,
    `时段编号` int NOT NULL,

    PRIMARY KEY (`科室编号`, `时段编号`),
    KEY `fkIdx_104` (`科室编号`),
    CONSTRAINT `FK_104` FOREIGN KEY `fkIdx_104` (`科室编号`) REFERENCES `科室` (`科室编号`),
    KEY `fkIdx_107` (`时段编号`),
    CONSTRAINT `FK_107` FOREIGN KEY `fkIdx_107` (`时段编号`) REFERENCES `时段` (`时段编号`)
);

-- ****************** SqlDBM: MySQL ******************;
-- ***************************************************;


-- ************************************** `医生接诊安排`

CREATE TABLE `医生接诊安排`
(
    `医生编号`   int NOT NULL,
    `科室编号`   int NOT NULL,
    `时段编号`   int NOT NULL,
    `门诊开放`   int NOT NULL,
    `接诊人数上限` int NOT NULL,

    PRIMARY KEY (`医生编号`, `科室编号`, `时段编号`),
    KEY `fkIdx_112` (`医生编号`),
    CONSTRAINT `FK_112` FOREIGN KEY `fkIdx_112` (`医生编号`) REFERENCES `医生资料` (`医生编号`),
    KEY `fkIdx_115` (`科室编号`, `时段编号`),
    CONSTRAINT `FK_115` FOREIGN KEY `fkIdx_115` (`科室编号`, `时段编号`) REFERENCES `科室接诊计划` (`科室编号`, `时段编号`)
);

-- ****************** SqlDBM: MySQL ******************;
-- ***************************************************;


-- ************************************** `预约`

-- ****************** SqlDBM: MySQL ******************;
-- ***************************************************;


-- ************************************** `预约`

CREATE TABLE `预约`
(
 `病人编号` int NOT NULL ,
 `医生编号` int NOT NULL ,
 `科室编号` int NOT NULL ,
 `时段编号` int NOT NULL ,
 `预约日期` date NOT NULL ,
 `是否就诊` int NOT NULL ,
 `评分`   int NULL ,
 `挂号类别` int NOT NULL ,

PRIMARY KEY (`病人编号`, `医生编号`, `科室编号`, `时段编号`, `预约日期`),
KEY `fkIdx_125` (`医生编号`, `科室编号`, `时段编号`),
CONSTRAINT `FK_125` FOREIGN KEY `fkIdx_125` (`医生编号`, `科室编号`, `时段编号`) REFERENCES `医生接诊安排` (`医生编号`, `科室编号`, `时段编号`),
KEY `fkIdx_99` (`病人编号`),
CONSTRAINT `FK_99` FOREIGN KEY `fkIdx_99` (`病人编号`) REFERENCES `病人资料` (`病人编号`)
);

-- ****************** SqlDBM: MySQL ******************;
-- ***************************************************;


-- ************************************** `事件`

CREATE TABLE `事件`
(
 `医生编号` int NOT NULL ,
 `政策`   int NOT NULL ,
 `科室编号` int NOT NULL ,
 `时段编号` int NOT NULL ,
 `日期`   date NOT NULL ,

PRIMARY KEY (`医生编号`, `科室编号`, `时段编号`, `日期`),
KEY `fkIdx_157` (`医生编号`, `科室编号`, `时段编号`),
CONSTRAINT `FK_157` FOREIGN KEY `fkIdx_157` (`医生编号`, `科室编号`, `时段编号`) REFERENCES `医生接诊安排` (`医生编号`, `科室编号`, `时段编号`)
);





































