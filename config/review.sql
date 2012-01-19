-- phpMyAdmin SQL Dump
-- version 3.4.9
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Jan 19, 2012 at 02:54 PM
-- Server version: 5.1.56
-- PHP Version: 5.3.9-pl0-gentoo

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `review`
--

-- --------------------------------------------------------

--
-- Table structure for table `rev_admin_blocks`
--

CREATE TABLE IF NOT EXISTS `rev_admin_blocks` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(32) NOT NULL COMMENT 'Name shown in the admin tab list',
  `block_id` smallint(5) unsigned NOT NULL COMMENT 'The id of the block implementing this admin function',
  `position` smallint(5) unsigned NOT NULL COMMENT 'This entry''s position in the tab bar (left end = 0)',
  PRIMARY KEY (`id`),
  KEY `position` (`position`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the list of currently available admin blocks' AUTO_INCREMENT=4 ;

--
-- Dumping data for table `rev_admin_blocks`
--

INSERT INTO `rev_admin_blocks` (`id`, `title`, `block_id`, `position`) VALUES
(1, 'Stats', 9, 0),
(2, 'Periods', 1, 1),
(3, 'Cohorts', 1, 2);

-- --------------------------------------------------------

--
-- Table structure for table `rev_blocks`
--

CREATE TABLE IF NOT EXISTS `rev_blocks` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique ID for this block entry',
  `name` varchar(32) NOT NULL,
  `module_id` smallint(5) unsigned NOT NULL COMMENT 'ID of the module implementing this block',
  `args` varchar(128) NOT NULL COMMENT 'Arguments passed verbatim to the block module',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='web-accessible page modules' AUTO_INCREMENT=10 ;

--
-- Dumping data for table `rev_blocks`
--

INSERT INTO `rev_blocks` (`id`, `name`, `module_id`, `args`) VALUES
(1, 'core', 1, ''),
(2, 'login', 2, ''),
(3, 'statements', 3, ''),
(4, 'map', 4, ''),
(5, 'config', 5, ''),
(6, 'sort', 6, ''),
(7, 'save', 7, ''),
(8, 'summary', 8, ''),
(9, 'admin', 9, '');

-- --------------------------------------------------------

--
-- Table structure for table `rev_cohorts`
--

CREATE TABLE IF NOT EXISTS `rev_cohorts` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `start_year` smallint(5) unsigned NOT NULL COMMENT 'The year the cohort started their academic career',
  `name` varchar(80) DEFAULT NULL COMMENT 'Human-readable name for the cohort',
  PRIMARY KEY (`id`),
  KEY `start_year` (`start_year`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the details of cohorts in the system' AUTO_INCREMENT=4 ;

--
-- Dumping data for table `rev_cohorts`
--

INSERT INTO `rev_cohorts` (`id`, `start_year`, `name`) VALUES
(1, 2009, 'Sept 2009 intake'),
(2, 2010, 'Sept 2010 intake'),
(3, 2011, 'Sept 2011 intake');

-- --------------------------------------------------------

--
-- Table structure for table `rev_cohorts_formfields`
--

CREATE TABLE IF NOT EXISTS `rev_cohorts_formfields` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique id for this formfield mapping',
  `cohort_id` int(10) unsigned NOT NULL COMMENT 'The id of the cohort this is a formfield for',
  `field_id` int(10) unsigned NOT NULL COMMENT 'The id of the formfield entry',
  `position` smallint(6) NOT NULL COMMENT 'The position of the field in the form',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the mapping from cohorts to form fields' AUTO_INCREMENT=25 ;

--
-- Dumping data for table `rev_cohorts_formfields`
--

INSERT INTO `rev_cohorts_formfields` (`id`, `cohort_id`, `field_id`, `position`) VALUES
(1, 1, 1, 1),
(2, 1, 2, 2),
(3, 1, 3, 3),
(4, 1, 4, 4),
(5, 1, 5, 5),
(6, 1, 6, 6),
(7, 1, 7, 7),
(8, 1, 8, 8),
(9, 2, 1, 1),
(10, 2, 2, 2),
(11, 2, 3, 3),
(12, 2, 4, 4),
(13, 2, 5, 5),
(14, 2, 6, 6),
(15, 2, 7, 7),
(16, 2, 8, 8),
(17, 3, 1, 1),
(18, 3, 2, 2),
(19, 3, 3, 3),
(20, 3, 4, 4),
(21, 3, 5, 5),
(22, 3, 6, 6),
(23, 3, 7, 7),
(24, 3, 8, 8);

-- --------------------------------------------------------

--
-- Table structure for table `rev_cohorts_maps`
--

CREATE TABLE IF NOT EXISTS `rev_cohorts_maps` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique id for this map mapping',
  `cohort_id` int(10) unsigned NOT NULL COMMENT 'Cohort this is a map entry for',
  `map_id` int(10) unsigned NOT NULL COMMENT 'The id of the map entry',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='MAps flashq map entries to cohorts' AUTO_INCREMENT=28 ;

--
-- Dumping data for table `rev_cohorts_maps`
--

INSERT INTO `rev_cohorts_maps` (`id`, `cohort_id`, `map_id`) VALUES
(1, 1, 1),
(2, 1, 2),
(3, 1, 3),
(4, 1, 4),
(5, 1, 5),
(6, 1, 6),
(7, 1, 7),
(8, 1, 8),
(9, 1, 9),
(10, 2, 1),
(11, 2, 2),
(12, 2, 3),
(13, 2, 4),
(14, 2, 5),
(15, 2, 6),
(16, 2, 7),
(17, 2, 8),
(18, 2, 9),
(19, 3, 1),
(20, 3, 2),
(21, 3, 3),
(22, 3, 4),
(23, 3, 5),
(24, 3, 6),
(25, 3, 7),
(26, 3, 8),
(27, 3, 9);

-- --------------------------------------------------------

--
-- Table structure for table `rev_cohorts_statements`
--

CREATE TABLE IF NOT EXISTS `rev_cohorts_statements` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `cohort_id` int(10) unsigned NOT NULL COMMENT 'The cohort sing this statement',
  `statement_id` int(10) unsigned NOT NULL COMMENT 'The id of the statement',
  PRIMARY KEY (`id`),
  KEY `cohort_id` (`cohort_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Maps statements to cohorts so that cohorts may retain consis' AUTO_INCREMENT=88 ;

--
-- Dumping data for table `rev_cohorts_statements`
--

INSERT INTO `rev_cohorts_statements` (`id`, `cohort_id`, `statement_id`) VALUES
(1, 1, 1),
(2, 1, 2),
(3, 1, 3),
(4, 1, 4),
(5, 1, 5),
(6, 1, 6),
(7, 1, 7),
(8, 1, 8),
(9, 1, 9),
(10, 1, 10),
(11, 1, 11),
(12, 1, 12),
(13, 1, 13),
(14, 1, 14),
(15, 1, 15),
(16, 1, 16),
(17, 1, 17),
(18, 1, 18),
(19, 1, 19),
(20, 1, 20),
(21, 1, 21),
(22, 1, 22),
(23, 1, 23),
(24, 1, 24),
(25, 1, 25),
(26, 1, 26),
(27, 1, 27),
(28, 1, 28),
(29, 1, 29),
(30, 2, 1),
(31, 2, 2),
(32, 2, 3),
(33, 2, 4),
(34, 2, 5),
(35, 2, 6),
(36, 2, 7),
(37, 2, 8),
(38, 2, 9),
(39, 2, 10),
(40, 2, 11),
(41, 2, 12),
(42, 2, 13),
(43, 2, 14),
(44, 2, 15),
(45, 2, 16),
(46, 2, 17),
(47, 2, 18),
(48, 2, 19),
(49, 2, 20),
(50, 2, 21),
(51, 2, 22),
(52, 2, 23),
(53, 2, 24),
(54, 2, 25),
(55, 2, 26),
(56, 2, 27),
(57, 2, 28),
(58, 2, 29),
(59, 3, 1),
(60, 3, 2),
(61, 3, 3),
(62, 3, 4),
(63, 3, 5),
(64, 3, 6),
(65, 3, 7),
(66, 3, 8),
(67, 3, 9),
(68, 3, 10),
(69, 3, 11),
(70, 3, 12),
(71, 3, 13),
(72, 3, 14),
(73, 3, 15),
(74, 3, 16),
(75, 3, 17),
(76, 3, 18),
(77, 3, 19),
(78, 3, 20),
(79, 3, 21),
(80, 3, 22),
(81, 3, 23),
(82, 3, 24),
(83, 3, 25),
(84, 3, 26),
(85, 3, 27),
(86, 3, 28),
(87, 3, 29);

-- --------------------------------------------------------

--
-- Table structure for table `rev_formfields`
--

CREATE TABLE IF NOT EXISTS `rev_formfields` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique id for this form field',
  `label` varchar(128) NOT NULL COMMENT 'The label to show for this form field',
  `note` varchar(255) DEFAULT NULL COMMENT 'Optional note to show with this form field',
  `type` enum('text','textarea','radio','select','checkbox','rating2','rating5','rating10') NOT NULL DEFAULT 'text' COMMENT 'The type of input this represents',
  `value` text NOT NULL COMMENT 'The default value (or checkbox options, etc)',
  `required` tinyint(1) NOT NULL COMMENT 'Is this field required?',
  `maxlength` smallint(5) unsigned DEFAULT NULL COMMENT 'Optional maximum length for this field',
  `restricted` varchar(80) DEFAULT NULL COMMENT 'Optional input value restriction',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores data about form fields for stage 5 of the flashq' AUTO_INCREMENT=9 ;

--
-- Dumping data for table `rev_formfields`
--

INSERT INTO `rev_formfields` (`id`, `label`, `note`, `type`, `value`, `required`, `maxlength`, `restricted`) VALUES
(1, 'Age', 'Please enter your year of birth (YYYY, eg. 1980).', 'text', '', 1, 4, '0-9'),
(2, 'Gender', 'Please select your gender.', 'radio', 'female;male', 1, NULL, NULL),
(3, 'Nationality', 'Please enter your nationality.', 'textarea', '', 1, NULL, NULL),
(4, 'What course are you on?', NULL, 'radio', 'Artificial Intelligence;Computer Science;Computer Science and Maths;Computer Science with Business Management;Computer Systems Engineering;Computing for Business Applications;Distributed Computing;Internet Computing;Software Engineering', 1, NULL, NULL),
(5, 'Is your course (tick all that apply)…', NULL, 'checkbox', 'MEng;BSc;BEng;with Industrial Experience', 1, NULL, NULL),
(6, 'How would you rate your level of experience of programming before coming to University?*', NULL, 'radio', 'Expert;Advanced;Competent;Beginner;No experience', 1, NULL, NULL),
(7, 'Please enter any feedback you have on using this software to do your sort.', NULL, 'textarea', '', 0, NULL, NULL),
(8, 'Please enter any additional comments you would like to add.', NULL, 'textarea', '', 0, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `rev_log`
--

CREATE TABLE IF NOT EXISTS `rev_log` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `logtime` int(10) unsigned NOT NULL COMMENT 'The time the logged event happened at',
  `user_id` int(10) unsigned DEFAULT NULL COMMENT 'The id of the user who triggered the event, if any',
  `ipaddr` varchar(16) DEFAULT NULL COMMENT 'The IP address the event was triggered from',
  `logtype` varchar(64) NOT NULL COMMENT 'The event type',
  `logdata` varchar(255) DEFAULT NULL COMMENT 'Any data that might be appropriate to log for this event',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores a log of events in the system.' ;

--
-- Table structure for table `rev_maps`
--

CREATE TABLE IF NOT EXISTS `rev_maps` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique ID for this map entry',
  `flashq_id` tinyint(4) NOT NULL COMMENT 'The ID to use in the map sent to flashq',
  `count` tinyint(3) unsigned NOT NULL COMMENT 'Numbe rof rows available in this column',
  `colour` char(6) DEFAULT NULL COMMENT 'Optional column colour',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores map column data' AUTO_INCREMENT=10 ;

--
-- Dumping data for table `rev_maps`
--

INSERT INTO `rev_maps` (`id`, `flashq_id`, `count`, `colour`) VALUES
(1, -4, 2, 'FFD5D5'),
(2, -3, 3, 'FFD5D5'),
(3, -2, 3, 'FFD5D5'),
(4, -1, 4, 'FFD5D5'),
(5, 0, 5, 'E9E9E9'),
(6, 1, 4, '9FDFBF'),
(7, 2, 3, '9FDFBF'),
(8, 3, 3, '9FDFBF'),
(9, 4, 2, '9FDFBF');

-- --------------------------------------------------------

--
-- Table structure for table `rev_modules`
--

CREATE TABLE IF NOT EXISTS `rev_modules` (
  `module_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique module id',
  `name` varchar(80) NOT NULL COMMENT 'Short name for the module',
  `perl_module` varchar(128) NOT NULL COMMENT 'Name of the perl module in blocks/ (no .pm extension!)',
  `active` tinyint(1) unsigned NOT NULL COMMENT 'Is this module enabled?',
  PRIMARY KEY (`module_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Available site modules, perl module names, and status' AUTO_INCREMENT=10 ;

--
-- Dumping data for table `rev_modules`
--

INSERT INTO `rev_modules` (`module_id`, `name`, `perl_module`, `active`) VALUES
(1, 'core', 'ReviewCore', 1),
(2, 'login', 'Login', 1),
(3, 'statements', 'XML::Statements', 1),
(4, 'map', 'XML::Map', 1),
(5, 'config', 'XML::Config', 1),
(6, 'sort', 'FlashQ', 1),
(7, 'save', 'SaveSort', 1),
(8, 'summary', 'Summary', 1),
(9, 'adminindex', 'Admin::Index', 1);

-- --------------------------------------------------------

--
-- Table structure for table `rev_sessions`
--

CREATE TABLE IF NOT EXISTS `rev_sessions` (
  `session_id` char(32) NOT NULL,
  `session_user_id` mediumint(9) unsigned NOT NULL,
  `session_start` int(11) unsigned NOT NULL,
  `session_time` int(11) unsigned NOT NULL,
  `session_ip` varchar(40) NOT NULL,
  `session_autologin` tinyint(1) unsigned NOT NULL,
  PRIMARY KEY (`session_id`),
  KEY `session_time` (`session_time`),
  KEY `session_user_id` (`session_user_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Website sessions';

-- --------------------------------------------------------

--
-- Table structure for table `rev_session_keys`
--

CREATE TABLE IF NOT EXISTS `rev_session_keys` (
  `key_id` char(32) COLLATE utf8_bin NOT NULL DEFAULT '',
  `user_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `last_ip` varchar(40) COLLATE utf8_bin NOT NULL DEFAULT '',
  `last_login` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`key_id`,`user_id`),
  KEY `last_login` (`last_login`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='Autologin keys';

-- --------------------------------------------------------

--
-- Table structure for table `rev_settings`
--

CREATE TABLE IF NOT EXISTS `rev_settings` (
  `name` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  `value` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci COMMENT='Site settings';

--
-- Dumping data for table `rev_settings`
--

INSERT INTO `rev_settings` (`name`, `value`) VALUES
('base', '/path/to/review'),
('scriptpath', '/review'),
('cookie_name', 'review'),
('cookie_path', '/'),
('cookie_domain', ''),
('cookie_secure', '1'),
('default_style', 'default'),
('force_style', '1'),
('logfile', ''),
('default_block', '1'),
('SSHCohortAuth:server', 'server.address.here'),
('SSHCohortAuth:timeout', '5'),
('SSHCohortAuth:binary', '/usr/bin/ssh'),
('SSHCohortAuth:anonymous', '1'),
('SSHCohortAuth:allow_autologin', '1'),
('SSHCohortAuth:max_autologin_time', '30'),
('SSHCohortAuth:ip_check', '4'),
('SSHCohortAuth:session_length', '3600'),
('SSHCohortAuth:session_gc', '7200'),
('Session:lastgc', '0'),
('SSHCohortAuth:unique_id', '2113'),
('Core:envelope_address', 'your@email.here'),
('Log:all_the_things', '1'),
('timefmt', '%d %b %Y %H:%M:%S'),
('XML::Config:negativeColour', '0xFFD5D5'),
('XML::Config:neutralColour', '0xE9E9E9'),
('XML::Config:positiveColour', '0x9FDFBF'),
('Core:truncate_length', '56'),
('SSHCohortAuth:admintype', '3');

-- --------------------------------------------------------

--
-- Table structure for table `rev_sorts`
--

CREATE TABLE IF NOT EXISTS `rev_sorts` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique id for the sort',
  `user_id` int(10) unsigned NOT NULL COMMENT 'ID of the user who did the sort',
  `period_id` int(10) unsigned NOT NULL COMMENT 'The id of the period the sort was done during',
  `sortdate` int(10) unsigned NOT NULL COMMENT 'The unix timestamp for the creation of this sort',
  `updated` int(10) unsigned NOT NULL COMMENT 'The unix timestamp of the last update to the sort',
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `semester_id` (`period_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores basic data for sorts - who did it and when';

-- --------------------------------------------------------

--
-- Table structure for table `rev_sorts_data`
--

CREATE TABLE IF NOT EXISTS `rev_sorts_data` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique id for this sort data',
  `sort_id` int(10) unsigned NOT NULL COMMENT 'The id of the sort this is data for',
  `name` varchar(80) NOT NULL COMMENT 'The name of the sort variable',
  `value` text NOT NULL COMMENT 'The text the user entered for the sort variable',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the sort data, justifications, and survey data for a ';
--
-- Table structure for table `rev_sorts_summaries`
--

CREATE TABLE IF NOT EXISTS `rev_sorts_summaries` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique is for the sort response',
  `sort_id` int(10) unsigned NOT NULL COMMENT 'The id of the sort this is a response to',
  `summary` text NOT NULL COMMENT 'The text entered by the student as a summary',
  `storetime` int(11) NOT NULL COMMENT 'The unix timestamp for when this resposne was added',
  PRIMARY KEY (`id`),
  KEY `sort_id` (`sort_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores all the responses made in relation to each sort.';


--
-- Table structure for table `rev_sort_periods`
--

CREATE TABLE IF NOT EXISTS `rev_sort_periods` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `year` smallint(6) unsigned NOT NULL COMMENT 'The academic year this is a semester in',
  `period` smallint(6) unsigned NOT NULL COMMENT 'A sort period number, usually a semester number (ie:1 or 2)',
  `startdate` int(10) unsigned NOT NULL COMMENT 'Unix timestamp of the start of the semester',
  `enddate` int(10) unsigned NOT NULL COMMENT 'Unix timestamp of the end of the semester',
  `name` varchar(80) NOT NULL COMMENT 'Human-readable semester name',
  `allow_sort` tinyint(1) unsigned DEFAULT '0' COMMENT 'Should users be able to perform sorts during this period?',
  PRIMARY KEY (`id`),
  KEY `startdate` (`startdate`),
  KEY `enddate` (`enddate`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the time periods during which users may do sorts' AUTO_INCREMENT=5 ;

--
-- Dumping data for table `rev_sort_periods`
--

INSERT INTO `rev_sort_periods` (`id`, `year`, `period`, `startdate`, `enddate`, `name`, `allow_sort`) VALUES
(1, 2011, 1, 1316390401, 1324079940, 'Semester 1', 1),
(2, 2011, 2, 1326672001, 1339199940, 'Semester 2', 1),
(3, 2011, 1, 1324079941, 1326204000, 'Christmas break', 1),
(4, 2011, 4, 1326204001, 1326672000, 'Testing period', 1);

-- --------------------------------------------------------

--
-- Table structure for table `rev_statements`
--

CREATE TABLE IF NOT EXISTS `rev_statements` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `statement` text NOT NULL COMMENT 'Text of the statement.',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Contains all the statements known to the system, both curren' AUTO_INCREMENT=30 ;

--
-- Dumping data for table `rev_statements`
--

INSERT INTO `rev_statements` (`id`, `statement`) VALUES
(1, 'I think I am a competent programmer'),
(2, 'I think I am a valuable team member'),
(3, 'I think I will use what I learnt in the modules last semester in my future career'),
(4, 'I think I could confidently use the technical skills I learnt in the last semester in industry right now'),
(5, 'I think I can improve my ability to learn'),
(6, 'I think I can improve my study skills'),
(7, 'I think what I learn in my modules is more important to me than the grades I get'),
(8, 'I think it is clear how the modules I did last semester are connected to other modules I have done so far'),
(9, 'I think this course is enabling me to become more involved with other students on the course'),
(10, 'I think what I am learning on this course will gain me respect from professionals in the industry'),
(11, 'I think the modules we did last semester are very relevant for where the Computing industry is heading'),
(12, 'I think the assessments in a module are the most important thing'),
(13, 'I think traditional lectures are the best way for experts to share their knowledge about Computing'),
(14, 'I think it is more important that lecturers have expert theoretical knowledge than experience in industry'),
(15, 'I think that students in a group can contribute as much to the learning of other students as the teachers'),
(16, 'I think it is best to know exactly what and when I am expected to learn and produce at the outset, than to adapt the requirements based on how I progress'),
(17, 'I think I have a good understanding of my strengths and weaknesses'),
(18, 'I think group work is the best way to learn'),
(19, 'I think my past experience is helping me to understand the concepts and skills I am learning in modules'),
(20, 'I think I have a clear idea of what I want to do after finishing my degree'),
(21, 'I think of myself as a good Computer Scientist'),
(22, 'I think I am a good student'),
(23, 'I think my fellow students do, or would, benefit from working with me'),
(24, 'I think the best thing about group work is the opportunity to learn from other students'),
(25, 'I think the best thing about group work is learning about how I perform in a group'),
(26, 'I think Computer Science is more of a natural science than a social science – it consists mostly of indisputable facts'),
(27, 'I think I can influence how the other students I work with learn'),
(28, 'I think being a good Computer Scientist means having good ‘people skills’'),
(29, 'I think the best Computer Scientists are those with extensive technical knowledge');

-- --------------------------------------------------------

--
-- Table structure for table `rev_users`
--

CREATE TABLE IF NOT EXISTS `rev_users` (
  `user_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_type` tinyint(3) unsigned DEFAULT '0' COMMENT 'The user type, 0 = normal, 3 = admin',
  `username` varchar(32) NOT NULL,
  `cohort_id` mediumint(8) unsigned DEFAULT NULL COMMENT 'The id of th ecohort this user belongs to. NULL = unknown.',
  `created` int(10) unsigned NOT NULL COMMENT 'The unix time at which this user was created',
  `last_login` int(10) unsigned NOT NULL COMMENT 'The unix time of th euser''s last login',
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `username` (`username`),
  KEY `cohort_id` (`cohort_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the local user data for each user in the system' AUTO_INCREMENT=2 ;

--
-- Dumping data for table `rev_users`
--

INSERT INTO `rev_users` (`user_id`, `user_type`, `username`, `cohort_id`, `created`, `last_login`) VALUES
(1, 0, 'anonymous', NULL, 1325763804, 1325763804);

-- --------------------------------------------------------

--
-- Table structure for table `rev_useryear_cache`
--

CREATE TABLE IF NOT EXISTS `rev_useryear_cache` (
  `username` varchar(40) NOT NULL COMMENT 'The username of the user',
  `year` smallint(5) unsigned NOT NULL COMMENT 'The academic year the user started in',
  PRIMARY KEY (`username`),
  KEY `year` (`year`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Caches username<>year associations to speed up cohort resolu';

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
