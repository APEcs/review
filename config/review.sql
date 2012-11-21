-- phpMyAdmin SQL Dump
-- version 2.11.10.1
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Nov 21, 2012 at 02:45 PM
-- Server version: 5.0.77
-- PHP Version: 5.1.6

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";


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
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `title` varchar(32) NOT NULL COMMENT 'Name shown in the admin tab list',
  `block_id` smallint(5) unsigned NOT NULL COMMENT 'The id of the block implementing this admin function',
  `position` smallint(5) unsigned NOT NULL COMMENT 'This entry''s position in the tab bar (left end = 0)',
  PRIMARY KEY  (`id`),
  KEY `position` (`position`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the list of currently available admin blocks' AUTO_INCREMENT=7 ;

--
-- Dumping data for table `rev_admin_blocks`
--

INSERT INTO `rev_admin_blocks` (`id`, `title`, `block_id`, `position`) VALUES
(1, 'Stats', 9, 0),
(2, 'Periods', 10, 1),
(3, 'Cohorts', 12, 2),
(4, 'Statements', 14, 3),
(5, 'Cohort statements', 15, 4),
(6, 'Form Fields', 17, 5);

-- --------------------------------------------------------

--
-- Table structure for table `rev_arcade_control`
--

CREATE TABLE IF NOT EXISTS `rev_arcade_control` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `yearoffset` tinyint(4) NOT NULL,
  `coursecode` varchar(9) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores courses and year offsets for UserCohort::ARCADE' AUTO_INCREMENT=7 ;

--
-- Dumping data for table `rev_arcade_control`
--

INSERT INTO `rev_arcade_control` (`id`, `yearoffset`, `coursecode`) VALUES
(1, 0, 'COMP10120'),
(2, -1, 'COMP23420'),
(3, -1, 'COMP26912'),
(4, -2, 'COMP30020'),
(5, -2, 'COMP30030'),
(6, -2, 'COMP30040');

-- --------------------------------------------------------

--
-- Table structure for table `rev_auth_methods`
--

CREATE TABLE IF NOT EXISTS `rev_auth_methods` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `perl_module` varchar(100) NOT NULL COMMENT 'The name of the AuthMethod (no .pm extension)',
  `priority` tinyint(4) NOT NULL COMMENT 'The authentication method''s priority. -128 = max, 127 = min',
  `enabled` tinyint(1) NOT NULL COMMENT 'Is this auth method usable?',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the authentication methods supported by the system' AUTO_INCREMENT=4 ;

--
-- Dumping data for table `rev_auth_methods`
--

INSERT INTO `rev_auth_methods` (`id`, `perl_module`, `priority`, `enabled`) VALUES
(1, 'AuthMethod::LDAPS', -127, 1),
(2, 'AuthMethod::Database', 0, 1),
(3, 'AuthMethod::SSH', 127, 1);

-- --------------------------------------------------------

--
-- Table structure for table `rev_auth_methods_params`
--

CREATE TABLE IF NOT EXISTS `rev_auth_methods_params` (
  `method_id` tinyint(4) NOT NULL COMMENT 'The id of the auth method',
  `name` varchar(40) NOT NULL COMMENT 'The parameter mame',
  `value` text NOT NULL COMMENT 'The value for the parameter',
  KEY `method_id` (`method_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Stores the settings for each auth method';

--
-- Dumping data for table `rev_auth_methods_params`
--

INSERT INTO `rev_auth_methods_params` (`method_id`, `name`, `value`) VALUES
(1, 'server', 'ldapm1.cs.man.ac.uk'),
(1, 'base', 'dc=cs,dc=man,dc=ac,dc=uk'),
(1, 'searchfield', 'uid'),
(2, 'table', 'rev_users'),
(2, 'userfield', 'username'),
(2, 'passfield', 'password'),
(3, 'server', 'soba.cs.man.ac.uk');

-- --------------------------------------------------------

--
-- Table structure for table `rev_blocks`
--

CREATE TABLE IF NOT EXISTS `rev_blocks` (
  `id` smallint(5) unsigned NOT NULL auto_increment COMMENT 'Unique ID for this block entry',
  `name` varchar(32) NOT NULL,
  `module_id` smallint(5) unsigned NOT NULL COMMENT 'ID of the module implementing this block',
  `args` varchar(128) NOT NULL COMMENT 'Arguments passed verbatim to the block module',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='web-accessible page modules' AUTO_INCREMENT=101 ;

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
(9, 'admin', 9, ''),
(10, 'periods', 10, ''),
(11, 'periodcheck', 11, ''),
(100, 'arcade', 100, ''),
(12, 'cohorts', 12, ''),
(13, 'cohortcheck', 13, ''),
(14, 'stateadmin', 14, ''),
(15, 'cstates', 15, ''),
(16, 'cstateapi', 16, ''),
(17, 'fields', 17, '');

-- --------------------------------------------------------

--
-- Table structure for table `rev_cohorts`
--

CREATE TABLE IF NOT EXISTS `rev_cohorts` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `startdate` int(10) unsigned NOT NULL COMMENT 'The date at which the cohort started',
  `enddate` int(10) unsigned NOT NULL COMMENT 'The last date on which a user can join this cohort',
  `name` varchar(80) default NULL COMMENT 'Human-readable name for the cohort',
  PRIMARY KEY  (`id`),
  KEY `start_year` (`startdate`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the details of cohorts in the system' AUTO_INCREMENT=6 ;

--
-- Dumping data for table `rev_cohorts`
--

INSERT INTO `rev_cohorts` (`id`, `startdate`, `enddate`, `name`) VALUES
(2, 1284937200, 1316386740, 'Sept 2010 intake'),
(3, 1316386800, 1347836340, 'Sept 2011 intake'),
(4, 1253487600, 1284937165, 'Sept 2009 intake'),
(5, 1347881881, 1435750680, 'Sept 2012 intake');

-- --------------------------------------------------------

--
-- Table structure for table `rev_cohorts_formfields`
--

CREATE TABLE IF NOT EXISTS `rev_cohorts_formfields` (
  `id` int(10) unsigned NOT NULL auto_increment COMMENT 'Unique id for this formfield mapping',
  `cohort_id` int(10) unsigned NOT NULL COMMENT 'The id of the cohort this is a formfield for',
  `field_id` int(10) unsigned NOT NULL COMMENT 'The id of the formfield entry',
  `position` smallint(6) NOT NULL COMMENT 'The position of the field in the form',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the mapping from cohorts to form fields' AUTO_INCREMENT=28 ;

--
-- Dumping data for table `rev_cohorts_formfields`
--

INSERT INTO `rev_cohorts_formfields` (`id`, `cohort_id`, `field_id`, `position`) VALUES
(6, 1, 6, 6),
(7, 1, 7, 7),
(8, 1, 8, 8),
(14, 2, 6, 6),
(15, 2, 7, 7),
(16, 2, 8, 8),
(27, 5, 8, 8),
(26, 5, 7, 7),
(25, 5, 6, 6),
(22, 3, 6, 6),
(23, 3, 7, 7),
(24, 3, 8, 8);

-- --------------------------------------------------------

--
-- Table structure for table `rev_cohorts_maps`
--

CREATE TABLE IF NOT EXISTS `rev_cohorts_maps` (
  `id` int(10) unsigned NOT NULL auto_increment COMMENT 'Unique id for this map mapping',
  `cohort_id` int(10) unsigned NOT NULL COMMENT 'Cohort this is a map entry for',
  `map_id` int(10) unsigned NOT NULL COMMENT 'The id of the map entry',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='MAps flashq map entries to cohorts' AUTO_INCREMENT=37 ;

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
(27, 3, 9),
(28, 5, 10),
(29, 5, 11),
(30, 5, 12),
(31, 5, 13),
(32, 5, 14),
(33, 5, 15),
(34, 5, 16),
(35, 5, 17),
(36, 5, 18);

-- --------------------------------------------------------

--
-- Table structure for table `rev_cohorts_statements`
--

CREATE TABLE IF NOT EXISTS `rev_cohorts_statements` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `cohort_id` int(10) unsigned NOT NULL COMMENT 'The cohort sing this statement',
  `statement_id` int(10) unsigned NOT NULL COMMENT 'The id of the statement',
  PRIMARY KEY  (`id`),
  KEY `cohort_id` (`cohort_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Maps statements to cohorts so that cohorts may retain consis' AUTO_INCREMENT=155 ;

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
(91, 2, 2),
(89, 2, 1),
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
(90, 2, 22),
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
(87, 3, 29),
(92, 4, 28),
(93, 4, 26),
(94, 4, 18),
(95, 4, 1),
(96, 4, 22),
(97, 4, 2),
(98, 4, 5),
(99, 4, 6),
(100, 4, 27),
(101, 4, 4),
(102, 4, 20),
(103, 4, 17),
(104, 4, 3),
(105, 4, 16),
(106, 4, 8),
(107, 4, 14),
(108, 4, 23),
(109, 4, 19),
(110, 4, 21),
(111, 4, 15),
(112, 4, 12),
(113, 4, 29),
(114, 4, 25),
(115, 4, 24),
(116, 4, 11),
(117, 4, 9),
(118, 4, 13),
(119, 4, 10),
(120, 4, 7),
(121, 5, 35),
(122, 5, 34),
(123, 5, 36),
(124, 5, 2),
(125, 5, 46),
(126, 5, 47),
(127, 5, 5),
(128, 5, 6),
(129, 5, 7),
(130, 5, 39),
(131, 5, 44),
(132, 5, 48),
(133, 5, 45),
(134, 5, 43),
(135, 5, 49),
(136, 5, 12),
(137, 5, 13),
(138, 5, 40),
(139, 5, 50),
(140, 5, 15),
(141, 5, 38),
(142, 5, 51),
(143, 5, 17),
(144, 5, 18),
(145, 5, 41),
(146, 5, 52),
(147, 5, 20),
(148, 5, 21),
(149, 5, 22),
(150, 5, 23),
(151, 5, 24),
(152, 5, 25),
(153, 5, 37),
(154, 5, 42);

-- --------------------------------------------------------

--
-- Table structure for table `rev_formfields`
--

CREATE TABLE IF NOT EXISTS `rev_formfields` (
  `id` int(10) unsigned NOT NULL auto_increment COMMENT 'Unique id for this form field',
  `label` varchar(128) NOT NULL COMMENT 'The label to show for this form field',
  `note` varchar(255) default NULL COMMENT 'Optional note to show with this form field',
  `type` enum('text','textarea','radio','select','checkbox','rating2','rating5','rating10') NOT NULL default 'text' COMMENT 'The type of input this represents',
  `value` text COMMENT 'The default value (or checkbox options, etc)',
  `scale` text COMMENT 'Scale arguments for rating2/5/10',
  `required` tinyint(1) default '0' COMMENT 'Is this field required?',
  `maxlength` smallint(5) unsigned default NULL COMMENT 'Optional maximum length for this field',
  `restricted` varchar(80) default NULL COMMENT 'Optional input value restriction',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores data about form fields for stage 5 of the flashq' AUTO_INCREMENT=9 ;

--
-- Dumping data for table `rev_formfields`
--

INSERT INTO `rev_formfields` (`id`, `label`, `note`, `type`, `value`, `scale`, `required`, `maxlength`, `restricted`) VALUES
(1, 'Age', 'Please enter your year of birth (YYYY, eg. 1980).', 'text', '', NULL, 1, 4, '0-9'),
(2, 'Gender', 'Please select your gender.', 'radio', 'female;male', NULL, 1, NULL, NULL),
(3, 'Nationality', 'Please enter your nationality.', 'textarea', '', NULL, 1, NULL, NULL),
(4, 'What course are you on?', NULL, 'radio', 'Artificial Intelligence;Computer Science;Computer Science and Maths;Computer Science with Business Management;Computer Systems Engineering;Computing for Business Applications;Distributed Computing;Internet Computing;Software Engineering', NULL, 1, NULL, NULL),
(5, 'Is your course (tick all that apply)...', NULL, 'checkbox', 'MEng;BSc;BEng;with Industrial Experience', NULL, 1, NULL, NULL),
(6, 'How would you rate your level of experience of programming before coming to University?', NULL, 'radio', 'Expert;Advanced;Competent;Beginner;No experience', NULL, 1, NULL, NULL),
(7, 'Please enter any feedback you have on using this software to do your sort.', NULL, 'textarea', '', NULL, 0, NULL, NULL),
(8, 'Please enter any additional comments you would like to add.', NULL, 'textarea', '', NULL, 0, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `rev_log`
--

CREATE TABLE IF NOT EXISTS `rev_log` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `logtime` int(10) unsigned NOT NULL COMMENT 'The time the logged event happened at',
  `user_id` int(10) unsigned default NULL COMMENT 'The id of the user who triggered the event, if any',
  `ipaddr` varchar(16) default NULL COMMENT 'The IP address the event was triggered from',
  `logtype` varchar(64) NOT NULL COMMENT 'The event type',
  `logdata` varchar(255) default NULL COMMENT 'Any data that might be appropriate to log for this event',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores a log of events in the system.' AUTO_INCREMENT=2053 ;

-- --------------------------------------------------------

--
-- Table structure for table `rev_maps`
--

CREATE TABLE IF NOT EXISTS `rev_maps` (
  `id` int(10) unsigned NOT NULL auto_increment COMMENT 'Unique ID for this map entry',
  `flashq_id` tinyint(4) NOT NULL COMMENT 'The ID to use in the map sent to flashq',
  `count` tinyint(3) unsigned NOT NULL COMMENT 'Numbe rof rows available in this column',
  `colour` char(6) default NULL COMMENT 'Optional column colour',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores map column data' AUTO_INCREMENT=19 ;

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
(9, 4, 2, '9FDFBF'),
(10, -4, 2, 'FFD5D5'),
(11, -3, 3, 'FFD5D5'),
(12, -2, 4, 'FFD5D5'),
(13, -1, 5, 'FFD5D5'),
(14, 0, 6, 'E9E9E9'),
(15, 1, 5, '9FDFBF'),
(16, 2, 4, '9FDFBF'),
(17, 3, 3, '9FDFBF'),
(18, 4, 2, '9FDFBF');

-- --------------------------------------------------------

--
-- Table structure for table `rev_modules`
--

CREATE TABLE IF NOT EXISTS `rev_modules` (
  `module_id` smallint(5) unsigned NOT NULL auto_increment COMMENT 'Unique module id',
  `name` varchar(80) NOT NULL COMMENT 'Short name for the module',
  `perl_module` varchar(128) NOT NULL COMMENT 'Name of the perl module in blocks/ (no .pm extension!)',
  `active` tinyint(1) unsigned NOT NULL COMMENT 'Is this module enabled?',
  PRIMARY KEY  (`module_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Available site modules, perl module names, and status' AUTO_INCREMENT=101 ;

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
(9, 'adminindex', 'Admin::Index', 1),
(10, 'adminperiods', 'Admin::Periods', 1),
(11, 'periodcheck', 'Admin::PeriodCheck', 1),
(100, 'arcade', 'UserCache::ARCADE', 1),
(12, 'admincohorts', 'Admin::Cohorts', 1),
(13, 'cohortcheck', 'Admin::CohortCheck', 1),
(14, 'stateadmin', 'Admin::Statements', 1),
(15, 'cohortstates', 'Admin::CohortStatements', 1),
(16, 'cstatesapi', 'Admin::CohortStateAPI', 1),
(17, 'fields', 'Admin::Fields', 1);

-- --------------------------------------------------------

--
-- Table structure for table `rev_sessions`
--

CREATE TABLE IF NOT EXISTS `rev_sessions` (
  `session_id` char(32) NOT NULL,
  `session_user_id` int(10) unsigned NOT NULL,
  `session_start` int(11) unsigned NOT NULL,
  `session_time` int(11) unsigned NOT NULL,
  `session_ip` varchar(40) NOT NULL,
  `session_autologin` tinyint(1) unsigned NOT NULL,
  PRIMARY KEY  (`session_id`),
  KEY `session_time` (`session_time`),
  KEY `session_user_id` (`session_user_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Website sessions';

-- --------------------------------------------------------

--
-- Table structure for table `rev_session_keys`
--

CREATE TABLE IF NOT EXISTS `rev_session_keys` (
  `key_id` char(32) collate utf8_bin NOT NULL default '',
  `user_id` int(10) unsigned NOT NULL default '0',
  `last_ip` varchar(40) collate utf8_bin NOT NULL default '',
  `last_login` int(11) unsigned NOT NULL default '0',
  PRIMARY KEY  (`key_id`,`user_id`),
  KEY `last_login` (`last_login`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='Autologin keys';

-- --------------------------------------------------------

--
-- Table structure for table `rev_settings`
--

CREATE TABLE IF NOT EXISTS `rev_settings` (
  `name` varchar(255) collate utf8_unicode_ci NOT NULL,
  `value` varchar(255) collate utf8_unicode_ci NOT NULL,
  PRIMARY KEY  (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci COMMENT='Site settings';

--
-- Dumping data for table `rev_settings`
--

INSERT INTO `rev_settings` (`name`, `value`) VALUES
('base', '/var/www/review'),
('scriptpath', '/review'),
('cookie_name', 'review'),
('cookie_path', '/'),
('cookie_domain', ''),
('cookie_secure', '1'),
('default_style', 'default'),
('force_style', '1'),
('logfile', ''),
('default_block', '1'),
('Auth:anonymous', '1'),
('Auth:allow_autologin', '1'),
('Auth:max_autologin_time', '30'),
('Auth:ip_check', '4'),
('Auth:session_length', '3600'),
('Auth:session_gc', '7200'),
('Session:lastgc', '1353084918'),
('Auth:unique_id', '2527'),
('Core:envelope_address', 'cpage@cs.man.ac.uk'),
('Log:all_the_things', '1'),
('timefmt', '%d %b %Y %H:%M:%S %Z'),
('XML::Config:negativeColour', '0xFFD5D5'),
('XML::Config:neutralColour', '0xE9E9E9'),
('XML::Config:positiveColour', '0x9FDFBF'),
('Core:truncate_length', '56'),
('Admin:shortlog_count', '10'),
('Admin:page_length', '20'),
('datefmt', '%d %b %Y'),
('Admin:period_minyear', '2010'),
('Admin:period_maxyear', '2038'),
('Auth:support_email', 'moodlesupport@cs.man.ac.uk'),
('Cohort:fallback_warning', '1'),
('Admin::Fields:truncate_length', '24');

-- --------------------------------------------------------

--
-- Table structure for table `rev_sorts`
--

CREATE TABLE IF NOT EXISTS `rev_sorts` (
  `id` int(10) unsigned NOT NULL auto_increment COMMENT 'Unique id for the sort',
  `user_id` int(10) unsigned NOT NULL COMMENT 'ID of the user who did the sort',
  `period_id` int(10) unsigned NOT NULL COMMENT 'The id of the period the sort was done during',
  `sortdate` int(10) unsigned NOT NULL COMMENT 'The unix timestamp for the creation of this sort',
  `updated` int(10) unsigned NOT NULL COMMENT 'The unix timestamp of the last update to the sort',
  PRIMARY KEY  (`id`),
  KEY `user_id` (`user_id`),
  KEY `semester_id` (`period_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores basic data for sorts - who did it and when' AUTO_INCREMENT=35 ;

--
-- Dumping data for table `rev_sorts`
--

INSERT INTO `rev_sorts` (`id`, `user_id`, `period_id`, `sortdate`, `updated`) VALUES
(14, 34, 8, 1349175193, 1349175193),
(2, 10, 2, 1329486762, 1329486762),
(3, 12, 2, 1329849410, 1329849410),
(4, 13, 2, 1329857676, 1329857676),
(5, 14, 2, 1329928549, 1329928549),
(6, 15, 2, 1329939063, 1329939063),
(7, 16, 2, 1329951133, 1329951133),
(8, 18, 2, 1329988969, 1329988969),
(9, 19, 2, 1330094346, 1330094346),
(10, 21, 2, 1330621461, 1330621461),
(15, 23, 8, 1349175219, 1349175219),
(16, 35, 8, 1349175325, 1349175325),
(17, 33, 8, 1349175349, 1349175349),
(18, 31, 8, 1349175363, 1349175363),
(19, 25, 8, 1349175364, 1349175364),
(20, 28, 8, 1349175377, 1349175377),
(21, 30, 8, 1349175469, 1349175469),
(22, 37, 8, 1349175531, 1349175531),
(23, 36, 8, 1349175532, 1349175532),
(24, 29, 8, 1349175556, 1349175556),
(25, 38, 8, 1349175599, 1349175599),
(26, 32, 8, 1349206886, 1349206886),
(27, 40, 8, 1349778354, 1349778354),
(28, 39, 8, 1349779213, 1349779213),
(29, 24, 8, 1350384943, 1350384943),
(30, 42, 8, 1350385061, 1350385061),
(31, 46, 8, 1350995298, 1350995298),
(32, 44, 8, 1350995714, 1350995714),
(33, 43, 8, 1350995840, 1350995840),
(34, 45, 8, 1350995980, 1350995980);

-- --------------------------------------------------------

--
-- Table structure for table `rev_sorts_data`
--

CREATE TABLE IF NOT EXISTS `rev_sorts_data` (
  `id` int(10) unsigned NOT NULL auto_increment COMMENT 'Unique id for this sort data',
  `sort_id` int(10) unsigned NOT NULL COMMENT 'The id of the sort this is data for',
  `name` varchar(80) NOT NULL COMMENT 'The name of the sort variable',
  `value` text NOT NULL COMMENT 'The text the user entered for the sort variable',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the sort data, justifications, and survey data for a ' AUTO_INCREMENT=647 ;

-- --------------------------------------------------------

--
-- Table structure for table `rev_sorts_summaries`
--

CREATE TABLE IF NOT EXISTS `rev_sorts_summaries` (
  `id` int(10) unsigned NOT NULL auto_increment COMMENT 'Unique is for the sort response',
  `sort_id` int(10) unsigned NOT NULL COMMENT 'The id of the sort this is a response to',
  `summary` text NOT NULL COMMENT 'The text entered by the student as a summary',
  `storetime` int(11) NOT NULL COMMENT 'The unix timestamp for when this resposne was added',
  PRIMARY KEY  (`id`),
  KEY `sort_id` (`sort_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores all the responses made in relation to each sort.' AUTO_INCREMENT=2 ;

--
-- Dumping data for table `rev_sorts_summaries`
--


-- --------------------------------------------------------

--
-- Table structure for table `rev_sort_periods`
--

CREATE TABLE IF NOT EXISTS `rev_sort_periods` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `year` smallint(6) unsigned NOT NULL COMMENT 'The academic year this is a semester in',
  `startdate` int(10) unsigned NOT NULL COMMENT 'Unix timestamp of the start of the semester',
  `enddate` int(10) unsigned NOT NULL COMMENT 'Unix timestamp of the end of the semester',
  `name` varchar(80) NOT NULL COMMENT 'Human-readable semester name',
  `allow_sort` tinyint(1) unsigned default '0' COMMENT 'Should users be able to perform sorts during this period?',
  PRIMARY KEY  (`id`),
  KEY `startdate` (`startdate`),
  KEY `enddate` (`enddate`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the time periods during which users may do sorts' AUTO_INCREMENT=10 ;

--
-- Dumping data for table `rev_sort_periods`
--

INSERT INTO `rev_sort_periods` (`id`, `year`, `startdate`, `enddate`, `name`, `allow_sort`) VALUES
(9, 2012, 1355097636, 1360368000, 'COMP10120 Sort 2', 1),
(2, 2011, 1326672000, 1339199940, 'Semester 2', 1),
(8, 2012, 1347836419, 1351468840, 'COMP10210 Sort 1', 1);

-- --------------------------------------------------------

--
-- Table structure for table `rev_statements`
--

CREATE TABLE IF NOT EXISTS `rev_statements` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `statement` text NOT NULL COMMENT 'Text of the statement.',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Contains all the statements known to the system, both curren' AUTO_INCREMENT=53 ;

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
(23, 'I think my fellow students do, or would, benefit from working with me '),
(24, 'I think the best thing about group work is the opportunity to learn from other students'),
(25, 'I think the best thing about group work is learning about how I perform in a group'),
(26, 'I think Computer Science is more of a natural science than a social science &mdash; it consists mostly of indisputable facts'),
(27, 'I think I can influence how the other students I work with learn'),
(28, 'I think being a good Computer Scientist means having good &quot;people skills&quot;'),
(29, 'I think the best Computer Scientists are those with extensive technical knowledge'),
(32, 'This is a test statement, it should not be used in actual sorts.'),
(34, 'I think Computer Science is more of a natural science than a social science &ndash; it consists mostly of unarguable facts'),
(35, 'I think being a good Computer Scientist means having good people skills'),
(36, 'I think I am a good programmer'),
(37, 'I think I can influence how the other students that I work with learn'),
(38, 'I think it is better for students to know exactly what and when we are expected to learn and produce at the start of a module, than to change the activities depending on how students are getting on'),
(39, 'I think it will be/is clear how the modules I do in semester 1 are connected to other modules in the course'),
(40, 'I think it is more important that lecturers have expert theoretical knowledge than practical experience in their field'),
(41, 'I think my past experience will help/is helping me to understand the concepts and skills needed for this module'),
(42, 'I think the best Computer Scientists are those with deep technical knowledge'),
(43, 'I think this module is very relevant for where the Computing industry is heading'),
(44, 'I think this module will enable me to become more involved with other students on the course'),
(45, 'I think what I learn/am learning on this module will gain me respect from professionals in the industry'),
(46, 'I think I will use what I learn/t in the module in semester 1 in my future career'),
(47, 'I think I could confidently use the technical skills I have right now to be successful in industry'),
(48, 'I think I will be able to use what I learn/have learnt on this module in other modules'),
(49, 'I think it is important to feel very connected with my group in group activities'),
(50, 'I think it is important that academic work is challenging both intellectually and practically'),
(51, 'I think this module will be/is a great starting point for learning Computer Science and I expect to learn more in the future through my own study'),
(52, 'I think what I learn/am learning in this module is/will be mostly new to me');

-- --------------------------------------------------------

--
-- Table structure for table `rev_usercohort_cache`
--

CREATE TABLE IF NOT EXISTS `rev_usercohort_cache` (
  `username` varchar(40) NOT NULL COMMENT 'The username of the user',
  `cohort_id` int(10) unsigned NOT NULL COMMENT 'The id of the cohort user is in',
  PRIMARY KEY  (`username`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Caches username<>year associations to speed up cohort resolu';

-- --------------------------------------------------------

--
-- Table structure for table `rev_users`
--

CREATE TABLE IF NOT EXISTS `rev_users` (
  `user_id` int(10) unsigned NOT NULL auto_increment,
  `user_auth` tinyint(3) unsigned default NULL COMMENT 'Id of the user''s auth method',
  `user_type` tinyint(3) unsigned default '0' COMMENT 'The user type, 0 = normal, 3 = admin',
  `username` varchar(32) NOT NULL,
  `password` char(59) default NULL,
  `cohort_id` mediumint(8) unsigned default NULL COMMENT 'The id of th ecohort this user belongs to. NULL = unknown.',
  `created` int(10) unsigned NOT NULL COMMENT 'The unix time at which this user was created',
  `last_login` int(10) unsigned NOT NULL COMMENT 'The unix time of th euser''s last login',
  PRIMARY KEY  (`user_id`),
  UNIQUE KEY `username` (`username`),
  KEY `cohort_id` (`cohort_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Stores the local user data for each user in the system' AUTO_INCREMENT=49 ;

--
-- Dumping data for table `rev_users`
--

INSERT INTO `rev_users` (`user_id`, `user_auth`, `user_type`, `username`, `password`, `cohort_id`, `created`, `last_login`) VALUES
(1, NULL, 0, 'anonymous', NULL, NULL, 1325763804, 1325763804);
