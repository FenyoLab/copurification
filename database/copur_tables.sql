-- MySQL dump 10.13  Distrib 5.7.27, for Linux (x86_64)
--
-- Host: localhost    Database: copur
-- ------------------------------------------------------
-- Server version	5.7.27

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `band`
--

DROP TABLE IF EXISTS `band`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `band` (
  `Id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `Lane_Id` int(10) unsigned NOT NULL,
  `Start_Position` int(10) unsigned NOT NULL,
  `End_Position` int(10) unsigned NOT NULL,
  `Mass` decimal(10,2) NOT NULL,
  `Quantity` decimal(10,2) DEFAULT NULL,
  `Mass_Error` decimal(10,2) DEFAULT NULL,
  `Quantity_Error` decimal(10,2) DEFAULT NULL,
  `Captured_Protein` tinyint(1) NOT NULL DEFAULT '0',
  `Used_for_Protein_Id` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `Lane_Id` (`Lane_Id`),
  CONSTRAINT `band_ibfk_1` FOREIGN KEY (`Lane_Id`) REFERENCES `lane` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=102075 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `band_protein`
--

DROP TABLE IF EXISTS `band_protein`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `band_protein` (
  `Band_Id` int(10) unsigned NOT NULL,
  `Protein_Id` int(10) unsigned NOT NULL,
  `MS_Search_Engine` varchar(32) DEFAULT NULL,
  `Protein_Id_Method` varchar(32) DEFAULT NULL,
  `MS_File_Suffix` varchar(10) DEFAULT NULL,
  PRIMARY KEY (`Band_Id`,`Protein_Id`),
  KEY `Protein_Id` (`Protein_Id`),
  CONSTRAINT `band_protein_ibfk_1` FOREIGN KEY (`Band_Id`) REFERENCES `band` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `band_protein_ibfk_2` FOREIGN KEY (`Protein_Id`) REFERENCES `protein_db_entry` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `experiment`
--

DROP TABLE IF EXISTS `experiment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `experiment` (
  `Id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `Project_Id` int(10) unsigned NOT NULL,
  `Experiment_Procedure_File` varchar(255) DEFAULT NULL,
  `Gel_Details_File` varchar(255) DEFAULT NULL,
  `Name` varchar(255) NOT NULL,
  `Species` varchar(255) NOT NULL,
  `Description` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `Project_Id` (`Project_Id`),
  KEY `Species` (`Species`),
  CONSTRAINT `experiment_ibfk_1` FOREIGN KEY (`Project_Id`) REFERENCES `project` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `experiment_ibfk_2` FOREIGN KEY (`Species`) REFERENCES `species` (`Name`)
) ENGINE=InnoDB AUTO_INCREMENT=700 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `gel`
--

DROP TABLE IF EXISTS `gel`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `gel` (
  `Id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `Experiment_Id` int(10) unsigned NOT NULL,
  `File_Id` tinyint(4) NOT NULL,
  `File_Type` varchar(255) NOT NULL,
  `Num_Lanes` tinyint(4) NOT NULL,
  `Public` tinyint(1) NOT NULL DEFAULT '0',
  `Citation` varchar(255) DEFAULT NULL,
  `Error_Description` varchar(255) DEFAULT NULL,
  `Display_Name` varchar(255) DEFAULT NULL,
  `Date_Submitted` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `XRef` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `Experiment_Id` (`Experiment_Id`),
  CONSTRAINT `gel_ibfk_1` FOREIGN KEY (`Experiment_Id`) REFERENCES `experiment` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=569 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ladder`
--

DROP TABLE IF EXISTS `ladder`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ladder` (
  `Id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=680 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ladder_mass`
--

DROP TABLE IF EXISTS `ladder_mass`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ladder_mass` (
  `Id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `Ladder_Id` int(10) unsigned NOT NULL,
  `Mass` decimal(10,2) NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `Ladder_Id` (`Ladder_Id`),
  CONSTRAINT `ladder_mass_ibfk_1` FOREIGN KEY (`Ladder_Id`) REFERENCES `ladder` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=7038 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lane`
--

DROP TABLE IF EXISTS `lane`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lane` (
  `Id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `Gel_Id` int(10) unsigned NOT NULL,
  `Lane_Order` tinyint(4) NOT NULL,
  `Error_Description` varchar(255) DEFAULT NULL,
  `Mol_Mass_Cal_Lane` tinyint(1) NOT NULL DEFAULT '0',
  `Quantity_Std_Cal_Lane` tinyint(1) NOT NULL DEFAULT '0',
  `Quantity_Std_Name` varchar(255) DEFAULT NULL,
  `Quantity_Std_Amount` decimal(10,2) DEFAULT NULL,
  `Quantity_Std_Units` varchar(255) DEFAULT NULL,
  `Quantity_Std_Size` decimal(10,2) DEFAULT NULL,
  `Ladder_Id` int(10) unsigned DEFAULT NULL,
  `Captured_Protein_Id` int(10) unsigned DEFAULT NULL,
  `Ph` decimal(4,2) DEFAULT NULL,
  `Over_Expressed` tinyint(1) DEFAULT NULL,
  `Tag_Location` varchar(255) DEFAULT NULL,
  `Tag_Type` varchar(255) DEFAULT NULL,
  `Antibody` varchar(255) DEFAULT NULL,
  `Other_Capture` varchar(255) DEFAULT NULL,
  `Notes` varchar(255) DEFAULT NULL,
  `Single_Reagent_Flag` tinyint(1) DEFAULT NULL,
  `MS_Search_Engine` varchar(32) DEFAULT NULL,
  `MS_File_Suffix` varchar(10) DEFAULT NULL,
  `Elution_Method` varchar(32) DEFAULT NULL,
  `Elution_Reagent` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `Gel_Id` (`Gel_Id`),
  KEY `Ladder_Id` (`Ladder_Id`),
  KEY `Captured_Protein_Id` (`Captured_Protein_Id`),
  KEY `Tag_Location` (`Tag_Location`),
  CONSTRAINT `lane_ibfk_1` FOREIGN KEY (`Gel_Id`) REFERENCES `gel` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `lane_ibfk_2` FOREIGN KEY (`Ladder_Id`) REFERENCES `ladder` (`Id`) ON DELETE SET NULL,
  CONSTRAINT `lane_ibfk_3` FOREIGN KEY (`Captured_Protein_Id`) REFERENCES `protein_db_entry` (`Id`) ON DELETE SET NULL,
  CONSTRAINT `lane_ibfk_4` FOREIGN KEY (`Tag_Location`) REFERENCES `tag_locations` (`Name`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=11010 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lane_reagents`
--

DROP TABLE IF EXISTS `lane_reagents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lane_reagents` (
  `Id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `Lane_Id` int(10) unsigned NOT NULL,
  `Reagent_Id` int(10) unsigned NOT NULL,
  `Amount` decimal(10,2) NOT NULL,
  `Amount_Units` varchar(255) NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `Lane_Id` (`Lane_Id`),
  KEY `Reagent_Id` (`Reagent_Id`),
  CONSTRAINT `lane_reagents_ibfk_1` FOREIGN KEY (`Lane_Id`) REFERENCES `lane` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `lane_reagents_ibfk_2` FOREIGN KEY (`Reagent_Id`) REFERENCES `reagent` (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=29738 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `project`
--

DROP TABLE IF EXISTS `project`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `project` (
  `Id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `Project_Parent_Id` int(10) unsigned DEFAULT NULL,
  `User_Id` int(10) unsigned NOT NULL,
  `Name` varchar(255) NOT NULL,
  `Description` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `Project_Parent_Id` (`Project_Parent_Id`),
  KEY `User_Id` (`User_Id`),
  CONSTRAINT `project_ibfk_1` FOREIGN KEY (`Project_Parent_Id`) REFERENCES `project` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `project_ibfk_2` FOREIGN KEY (`User_Id`) REFERENCES `user` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=112 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `protein_db`
--

DROP TABLE IF EXISTS `protein_db`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `protein_db` (
  `Id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) NOT NULL,
  `Description` varchar(255) DEFAULT NULL,
  `Link` varchar(255) DEFAULT NULL,
  `Species` varchar(255) NOT NULL,
  `Priority` tinyint(4) NOT NULL DEFAULT '1',
  PRIMARY KEY (`Id`),
  KEY `Species` (`Species`),
  CONSTRAINT `protein_db_ibfk_1` FOREIGN KEY (`Species`) REFERENCES `species` (`Name`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `protein_db_entry`
--

DROP TABLE IF EXISTS `protein_db_entry`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `protein_db_entry` (
  `Id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `Protein_DB_Id` int(10) unsigned NOT NULL,
  `Systematic_Name` varchar(255) NOT NULL,
  `Common_Name` varchar(255) DEFAULT NULL,
  `Link` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `Protein_DB_Id` (`Protein_DB_Id`),
  CONSTRAINT `protein_db_entry_ibfk_1` FOREIGN KEY (`Protein_DB_Id`) REFERENCES `protein_db` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=113 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `reagent`
--

DROP TABLE IF EXISTS `reagent`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `reagent` (
  `Id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `Reagent_Type` varchar(255) NOT NULL,
  `Name` varchar(255) NOT NULL,
  `Short_Name` varchar(255) DEFAULT NULL,
  `Description` varchar(255) DEFAULT NULL,
  `Link` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `Reagent_Type` (`Reagent_Type`),
  CONSTRAINT `reagent_ibfk_1` FOREIGN KEY (`Reagent_Type`) REFERENCES `reagent_types` (`Name`)
) ENGINE=InnoDB AUTO_INCREMENT=327 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `reagent_types`
--

DROP TABLE IF EXISTS `reagent_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `reagent_types` (
  `Name` varchar(255) NOT NULL,
  `Display_Order` int(11) DEFAULT NULL,
  PRIMARY KEY (`Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `shared_projects`
--

DROP TABLE IF EXISTS `shared_projects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `shared_projects` (
  `Project_Id` int(10) unsigned NOT NULL,
  `User_Id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`Project_Id`,`User_Id`),
  KEY `User_Id` (`User_Id`),
  CONSTRAINT `shared_projects_ibfk_1` FOREIGN KEY (`Project_Id`) REFERENCES `project` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `shared_projects_ibfk_2` FOREIGN KEY (`User_Id`) REFERENCES `user` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `species`
--

DROP TABLE IF EXISTS `species`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `species` (
  `Name` varchar(255) NOT NULL,
  PRIMARY KEY (`Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tag_locations`
--

DROP TABLE IF EXISTS `tag_locations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tag_locations` (
  `Name` varchar(255) NOT NULL,
  PRIMARY KEY (`Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `user`
--

DROP TABLE IF EXISTS `user`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user` (
  `Id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `First_Name` varchar(255) DEFAULT NULL,
  `Last_Name` varchar(255) DEFAULT NULL,
  `Institution` varchar(255) DEFAULT NULL,
  `Title` varchar(255) DEFAULT NULL,
  `Email` varchar(255) NOT NULL,
  `Password` varbinary(64) NOT NULL,
  `ORCID` varchar(255) DEFAULT NULL,
  `Validated` tinyint(1) NOT NULL DEFAULT '0',
  `Active` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`Id`),
  UNIQUE KEY `Email` (`Email`)
) ENGINE=InnoDB AUTO_INCREMENT=85 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2023-08-21 17:39:41
