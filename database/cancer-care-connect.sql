-- =====================================================================
-- CANCERCARE CONNECT - Hope • Support • Together
-- Database: cancercare_connect
-- Engine: InnoDB | utf8mb4 | Works on XAMPP (MariaDB 10.4+) and MySQL 8
--
-- HOW TO IMPORT: phpMyAdmin -> Import tab -> choose this file -> Go.
-- WARNING: the first line drops the database, so re-importing resets all data.
-- All demo accounts use the password:  CancerCare@2024
-- =====================================================================

DROP DATABASE IF EXISTS `cancercare_connect`;
CREATE DATABASE `cancercare_connect` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `cancercare_connect`;

-- 1. users ------------------------------------------------------------
CREATE TABLE `users` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(150) NOT NULL,
  `email` VARCHAR(191) NOT NULL UNIQUE,
  `password_hash` VARCHAR(255) NOT NULL,
  `role` ENUM('patient','charity','verifier','admin') NOT NULL,
  `phone` VARCHAR(30) NOT NULL,
  `district` VARCHAR(50) NOT NULL,
  `status` ENUM('active','pending','suspended') NOT NULL DEFAULT 'active',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_users_role_status` (`role`,`status`),
  INDEX `idx_users_district` (`district`)
) ENGINE=InnoDB;

-- 2. aid_categories ---------------------------------------------------
CREATE TABLE `aid_categories` (
  `id` VARCHAR(30) PRIMARY KEY,
  `name` VARCHAR(100) NOT NULL,
  `description` TEXT,
  `default_lookback_days` INT UNSIGNED NOT NULL DEFAULT 30,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 3. patient_profiles -------------------------------------------------
-- Clinical fields are NULL until the patient completes the profile form.
CREATE TABLE `patient_profiles` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED NOT NULL UNIQUE,
  `patient_name` VARCHAR(150) NOT NULL,
  `nic_number` VARCHAR(20) NOT NULL UNIQUE,
  `date_of_birth` DATE NULL,
  `gender` ENUM('male','female','other') NULL,
  `guardian_name` VARCHAR(150) NULL,
  `guardian_nic` VARCHAR(20) NULL,
  `guardian_relationship` VARCHAR(50) NULL,
  `contact_number` VARCHAR(30) NOT NULL,
  `emergency_number` VARCHAR(30) NULL,
  `residential_address` TEXT NULL,
  `district` VARCHAR(50) NOT NULL,
  `grama_niladhari_division` VARCHAR(100) NULL,
  `primary_hospital` VARCHAR(150) NULL,
  `clinic_registration_number` VARCHAR(50) NULL,
  `diagnosis` VARCHAR(200) NULL,
  `cancer_stage` VARCHAR(50) NULL,
  `diagnosed_date` DATE NULL,
  `consultant_oncologist` VARCHAR(150) NULL,
  `verification_status` ENUM('pending','verified','needs_info','rejected') NOT NULL DEFAULT 'pending',
  `verified_at` DATETIME NULL,
  `verified_by_user_id` INT UNSIGNED NULL,
  `verification_notes` TEXT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`verified_by_user_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  INDEX `idx_patient_verification` (`verification_status`),
  INDEX `idx_patient_district` (`district`)
) ENGINE=InnoDB;

-- 4. patient_documents ------------------------------------------------
CREATE TABLE `patient_documents` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `patient_id` INT UNSIGNED NOT NULL,
  `document_type` ENUM('biopsy_report','hospital_clinic_book','oncologist_prescription','grama_niladhari_certificate','id_copy') NOT NULL,
  `title` VARCHAR(200) NOT NULL,
  `stored_filename` VARCHAR(255) NOT NULL,
  `original_filename` VARCHAR(255) NOT NULL,
  `file_size_bytes` INT UNSIGNED NOT NULL,
  `mime_type` VARCHAR(100) NOT NULL,
  `verification_status` ENUM('pending','verified','rejected') NOT NULL DEFAULT 'pending',
  `reviewer_notes` TEXT NULL,
  `uploaded_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`patient_id`) REFERENCES `patient_profiles`(`id`) ON DELETE CASCADE,
  INDEX `idx_doc_patient` (`patient_id`,`document_type`)
) ENGINE=InnoDB;

-- 5. patient_verifications (audit trail of verifier decisions) --------
CREATE TABLE `patient_verifications` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `patient_id` INT UNSIGNED NOT NULL,
  `verifier_user_id` INT UNSIGNED NOT NULL,
  `previous_status` ENUM('pending','verified','needs_info','rejected') NOT NULL,
  `new_status` ENUM('pending','verified','needs_info','rejected') NOT NULL,
  `clinical_notes` TEXT NOT NULL,
  `hospital_contacted` VARCHAR(150) NULL,
  `flagged_suspicious` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`patient_id`) REFERENCES `patient_profiles`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`verifier_user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 6. charities --------------------------------------------------------
CREATE TABLE `charities` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED NOT NULL UNIQUE,
  `organization_name` VARCHAR(200) NOT NULL,
  `registration_number` VARCHAR(100) NOT NULL UNIQUE,
  `established_year` SMALLINT UNSIGNED NOT NULL,
  `contact_person` VARCHAR(150) NOT NULL,
  `official_email` VARCHAR(191) NOT NULL,
  `phone` VARCHAR(50) NOT NULL,
  `headquarters_address` TEXT NOT NULL,
  `district` VARCHAR(50) NOT NULL,
  `operating_districts_json` JSON NOT NULL,
  `website_url` VARCHAR(255) NULL,
  `status` ENUM('pending_approval','approved','rejected','suspended') NOT NULL DEFAULT 'pending_approval',
  `approved_at` DATETIME NULL,
  `approved_by_admin_id` INT UNSIGNED NULL,
  `description` TEXT NOT NULL,
  `monthly_aid_capacity_lkr` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`approved_by_admin_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  INDEX `idx_charity_status` (`status`)
) ENGINE=InnoDB;

-- 7. charity_services -------------------------------------------------
CREATE TABLE `charity_services` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `charity_id` INT UNSIGNED NOT NULL,
  `category_id` VARCHAR(30) NOT NULL,
  `title` VARCHAR(200) NOT NULL,
  `description` TEXT NOT NULL,
  `eligibility_criteria` TEXT NOT NULL,
  `estimated_value_lkr` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `frequency` ENUM('one_time','monthly','per_hospital_visit') NOT NULL DEFAULT 'one_time',
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`charity_id`) REFERENCES `charities`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`category_id`) REFERENCES `aid_categories`(`id`) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 8. aid_requests -----------------------------------------------------
CREATE TABLE `aid_requests` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `request_number` VARCHAR(50) NOT NULL UNIQUE,
  `patient_id` INT UNSIGNED NOT NULL,
  `charity_id` INT UNSIGNED NOT NULL,
  `category_id` VARCHAR(30) NOT NULL,
  `service_id` INT UNSIGNED NULL,
  `urgency_level` ENUM('standard','high','critical') NOT NULL DEFAULT 'standard',
  `requested_amount_lkr` DECIMAL(10,2) NOT NULL,
  `description` TEXT NOT NULL,
  `hospital_appointment_date` DATE NULL,
  `prescription_details` TEXT NULL,
  `status` ENUM('submitted','under_review','duplicate_flagged','needs_more_info','approved','disbursed','rejected','cancelled') NOT NULL DEFAULT 'submitted',
  `duplicate_check_run` TINYINT(1) NOT NULL DEFAULT 0,
  `duplicate_warning_triggered` TINYINT(1) NOT NULL DEFAULT 0,
  `duplicate_warning_details` TEXT NULL,
  `duplicate_override_reason` TEXT NULL,
  `duplicate_overridden_by` INT UNSIGNED NULL,
  `review_notes` TEXT NULL,
  `decision_date` DATETIME NULL,
  `decided_by_user_id` INT UNSIGNED NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`patient_id`) REFERENCES `patient_profiles`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`charity_id`) REFERENCES `charities`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`category_id`) REFERENCES `aid_categories`(`id`) ON DELETE RESTRICT,
  FOREIGN KEY (`service_id`) REFERENCES `charity_services`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`duplicate_overridden_by`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`decided_by_user_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  INDEX `idx_req_patient_cat_status` (`patient_id`,`category_id`,`status`),
  INDEX `idx_req_charity_status` (`charity_id`,`status`)
) ENGINE=InnoDB;

-- 9. aid_history  (only CONFIRMED, delivered aid - feeds duplicate detection)
CREATE TABLE `aid_history` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `patient_id` INT UNSIGNED NOT NULL,
  `charity_id` INT UNSIGNED NOT NULL,
  `request_id` INT UNSIGNED NULL,
  `category_id` VARCHAR(30) NOT NULL,
  `service_title` VARCHAR(200) NOT NULL,
  `value_lkr` DECIMAL(10,2) NOT NULL,
  `disbursed_date` DATE NOT NULL,
  `receipt_number` VARCHAR(100) NOT NULL,
  `notes` TEXT NULL,
  `disbursed_by_user_id` INT UNSIGNED NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`patient_id`) REFERENCES `patient_profiles`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`charity_id`) REFERENCES `charities`(`id`) ON DELETE RESTRICT,
  FOREIGN KEY (`request_id`) REFERENCES `aid_requests`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`category_id`) REFERENCES `aid_categories`(`id`) ON DELETE RESTRICT,
  FOREIGN KEY (`disbursed_by_user_id`) REFERENCES `users`(`id`) ON DELETE RESTRICT,
  INDEX `idx_duplicate_lookup` (`patient_id`,`category_id`,`disbursed_date`)
) ENGINE=InnoDB;

-- 10. duplicate_aid_rules --------------------------------------------
CREATE TABLE `duplicate_aid_rules` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `category_id` VARCHAR(30) NOT NULL UNIQUE,
  `lookback_days` INT UNSIGNED NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `description` TEXT NOT NULL,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`category_id`) REFERENCES `aid_categories`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 11. notifications ---------------------------------------------------
CREATE TABLE `notifications` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `recipient_user_id` INT UNSIGNED NOT NULL,
  `title` VARCHAR(200) NOT NULL,
  `message` TEXT NOT NULL,
  `category` ENUM('request_update','verification','duplicate_warning','system','disbursement') NOT NULL,
  `is_read` TINYINT(1) NOT NULL DEFAULT 0,
  `related_request_id` INT UNSIGNED NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`recipient_user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`related_request_id`) REFERENCES `aid_requests`(`id`) ON DELETE SET NULL,
  INDEX `idx_notif_user_unread` (`recipient_user_id`,`is_read`)
) ENGINE=InnoDB;

-- 12. audit_logs ------------------------------------------------------
CREATE TABLE `audit_logs` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `user_id` INT UNSIGNED NULL,
  `user_role` VARCHAR(30) NULL,
  `module` VARCHAR(50) NOT NULL,
  `action` VARCHAR(100) NOT NULL,
  `details` TEXT NOT NULL,
  `ip_address` VARCHAR(45) NOT NULL,
  `severity` ENUM('info','warning','critical') NOT NULL DEFAULT 'info',
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  INDEX `idx_audit_module_timestamp` (`module`,`timestamp`),
  INDEX `idx_audit_severity` (`severity`)
) ENGINE=InnoDB;

-- =====================================================================
-- SEED DATA (fictional demonstration data)
-- =====================================================================
INSERT INTO `aid_categories` (`id`,`name`,`description`,`default_lookback_days`) VALUES
('food','Food & Nutrition','High-protein hampers, fortified milk powder and fresh nutrition',30),
('medicine','Medicine & Oncology Drugs','Chemotherapy drugs and supportive oncology prescriptions',60),
('transport','Hospital Transport & Travel','Train/bus subsidies and ambulance help to Maharagama or Kandy',14),
('shelter','Shelter & Patient Rest Homes','Subsidised temporary lodging during radiation / chemo cycles',90),
('emergency','Emergency Patient Grant','One-time grant for urgent scans or surgical consumables',180);

INSERT INTO `duplicate_aid_rules` (`category_id`,`lookback_days`,`description`) VALUES
('food',30,'One food basket every 30 days across all charities.'),
('medicine',60,'Medicine grants need a 60-day interval before repeat assistance.'),
('transport',14,'Travel allowance once every 14 days (matches chemo cycles).'),
('shelter',90,'Rest-home lodging once per 90-day radiotherapy cycle.'),
('emergency',180,'Emergency grant once per 180 days across the whole network.');

-- Demo users. Password for ALL of them: CancerCare@2024
INSERT INTO `users` (`id`,`name`,`email`,`password_hash`,`role`,`phone`,`district`,`status`) VALUES
(1,'Priyantha Jayawardena','patient@cancercare.lk','$2y$10$QaJ4yH0LA6KL.MQFLou0tOHMrjhWVpgXf5sUEyd1EyXfbjRSYToKi','patient','+94 77 452 9811','Galle','active'),
(2,'Sri Lanka Cancer Society','charity@cancercare.lk','$2y$10$QaJ4yH0LA6KL.MQFLou0tOHMrjhWVpgXf5sUEyd1EyXfbjRSYToKi','charity','+94 11 258 5879','Colombo','active'),
(3,'Mrs. Kusuma Ranasinghe (Social Services)','verifier@cancercare.lk','$2y$10$QaJ4yH0LA6KL.MQFLou0tOHMrjhWVpgXf5sUEyd1EyXfbjRSYToKi','verifier','+94 11 285 0253','Colombo','active'),
(4,'K. S. Mendis (System Administrator)','admin@cancercare.lk','$2y$10$QaJ4yH0LA6KL.MQFLou0tOHMrjhWVpgXf5sUEyd1EyXfbjRSYToKi','admin','+94 77 123 4567','Colombo','active'),
(5,'Nirmala Kumari Weerasinghe','patient2@cancercare.lk','$2y$10$QaJ4yH0LA6KL.MQFLou0tOHMrjhWVpgXf5sUEyd1EyXfbjRSYToKi','patient','+94 71 893 2140','Kurunegala','active'),
(6,'Suwa Arana Care Foundation','charity2@cancercare.lk','$2y$10$QaJ4yH0LA6KL.MQFLou0tOHMrjhWVpgXf5sUEyd1EyXfbjRSYToKi','charity','+94 11 289 4432','Colombo','active'),
(7,'Hope Cancer Care Trust','charity3@cancercare.lk','$2y$10$QaJ4yH0LA6KL.MQFLou0tOHMrjhWVpgXf5sUEyd1EyXfbjRSYToKi','charity','+94 11 258 0000','Colombo','active');

INSERT INTO `patient_profiles`
(`id`,`user_id`,`patient_name`,`nic_number`,`date_of_birth`,`gender`,`guardian_name`,`guardian_nic`,`guardian_relationship`,`contact_number`,`emergency_number`,`residential_address`,`district`,`grama_niladhari_division`,`primary_hospital`,`clinic_registration_number`,`diagnosis`,`cancer_stage`,`diagnosed_date`,`consultant_oncologist`,`verification_status`,`verified_at`,`verified_by_user_id`,`verification_notes`)
VALUES
(1,1,'Priyantha Jayawardena','197412803450','1974-05-18','male','Sunethra Jayawardena','197864502391','Spouse','+94 77 452 9811','+94 77 000 1111','No. 44, Temple Road, Weligama','Galle','Weligama West 412/A','Apeksha Hospital Maharagama (National Cancer Institute of Sri Lanka)','MH-2024-8841','Stage III Colorectal Adenocarcinoma','Stage III','2023-11-20','Dr. Rohan De Silva','verified','2024-01-15 10:30:00',3,'Verified against Apeksha clinic registry MH-2024-8841.'),
(2,5,'Nirmala Kumari Weerasinghe','198254201889','1982-08-14','female','Ajith Weerasinghe','198011204899','Brother','+94 71 893 2140','+94 37 222 1890','Aluthwatte, Narammala','Kurunegala','Narammala North 519','Teaching Hospital Kandy (Cancer Treatment Center)','KND-1092','Invasive Ductal Carcinoma','Stage IIB','2024-01-08','Dr. Chaminda Jayatissa','pending',NULL,NULL,NULL);

-- (No demo documents: upload a real PDF/JPG as a patient to try the document workflow.)

INSERT INTO `charities`
(`id`,`user_id`,`organization_name`,`registration_number`,`established_year`,`contact_person`,`official_email`,`phone`,`headquarters_address`,`district`,`operating_districts_json`,`website_url`,`status`,`approved_at`,`approved_by_admin_id`,`description`,`monthly_aid_capacity_lkr`)
VALUES
(1,2,'Sri Lanka Cancer Society','NGO-SL-1948-001',1948,'Mr. Rohan Perera','welfare@cancercaresl.org','+94 11 258 5879','37/25, Bullers Lane, Colombo 07','Colombo','["Colombo","Gampaha","Kalutara","Kandy","Galle","Kurunegala"]',NULL,'approved','2023-11-15 00:00:00',4,'National non-governmental cancer relief organisation founded in 1948.',2500000.00),
(2,6,'Suwa Arana Care Foundation','NGO-SL-2016-104',2016,'Dr. Shantha Abeykoon','help@suwaarana.lk','+94 11 289 4432','15, Templers Road, Mount Lavinia','Colombo','["Colombo","Gampaha","Kalutara","Galle"]',NULL,'approved','2023-12-15 00:00:00',4,'Temporary hospice accommodation, convalescent meals and hospital shuttles for outstation patients.',1800000.00),
(3,7,'Hope Cancer Care Trust','NGO-78291',2020,'Mr. Nimal Fernando','contact@hopecancer.org','+94 11 258 0000','37/25, High Level Road, Colombo','Colombo','["Colombo","Gampaha","Kalutara"]',NULL,'pending_approval',NULL,NULL,'Nutrition packages, prescription support and transport assistance. Awaiting admin approval.',2000000.00);

INSERT INTO `charity_services` (`charity_id`,`category_id`,`title`,`description`,`eligibility_criteria`,`estimated_value_lkr`,`frequency`) VALUES
(1,'food','Monthly Wholesome Nutrition Hamper','Rice, dhal, eggs, milk powder and nutrition supplements.','Verified cancer patient on active treatment.',12500.00,'monthly'),
(1,'transport','Chemotherapy Travel Subsidy','Train/bus and taxi allowance to the treatment hospital.','Outstation patient with a clinic appointment.',8500.00,'per_hospital_visit'),
(1,'medicine','Chemotherapy Drug Support Grant','Partial funding for drugs not available in the state hospital.','Prescription from a consultant oncologist.',45000.00,'one_time'),
(2,'shelter','Patient Rest-Home Stay','Dormitory stay with meals near Apeksha Hospital.','Outstation patient on radiation or multi-day chemo.',30000.00,'one_time'),
(2,'food','Convalescent Meal Pack','Prepared nutritious meals for two weeks.','Verified patient; priority for post-surgery patients.',9000.00,'one_time');

-- Past DELIVERED aid for patient 1 (this is what triggers duplicate warnings)
INSERT INTO `aid_requests` (`id`,`request_number`,`patient_id`,`charity_id`,`category_id`,`service_id`,`urgency_level`,`requested_amount_lkr`,`description`,`status`,`duplicate_check_run`,`decision_date`,`decided_by_user_id`) VALUES
(1,'CCC-REQ-2026-00001',1,1,'food',1,'standard',12500.00,'Monthly hamper','disbursed',1,NOW(),2),
(2,'CCC-REQ-2026-00002',1,1,'transport',2,'standard',8500.00,'Travel to Maharagama','disbursed',1,NOW(),2);

INSERT INTO `aid_history` (`patient_id`,`charity_id`,`request_id`,`category_id`,`service_title`,`value_lkr`,`disbursed_date`,`receipt_number`,`notes`,`disbursed_by_user_id`) VALUES
(1,1,1,'food','Monthly Wholesome Nutrition Hamper',12500.00,DATE_SUB(CURRENT_DATE, INTERVAL 13 DAY),'SLCS-REC-0192','Hamper delivered to Weligama.',2),
(1,1,2,'transport','Chemotherapy Travel Subsidy',8500.00,DATE_SUB(CURRENT_DATE, INTERVAL 25 DAY),'SLCS-REC-0110','Train + taxi Galle to Maharagama.',2);

-- One request waiting in the charity's queue
INSERT INTO `aid_requests` (`id`,`request_number`,`patient_id`,`charity_id`,`category_id`,`service_id`,`urgency_level`,`requested_amount_lkr`,`description`,`prescription_details`,`status`,`duplicate_check_run`,`duplicate_warning_details`) VALUES
(3,'CCC-REQ-2026-00003',1,1,'medicine',3,'high',45000.00,'Need support for next two chemotherapy cycles.','Oxaliplatin + Capecitabine per oncologist prescription.','submitted',1,'Clean record: no medicine aid in the last 60 days.');

INSERT INTO `notifications` (`recipient_user_id`,`title`,`message`,`category`) VALUES
(1,'Welcome to CancerCare Connect','Your medical profile is verified. You can now request aid from approved charities.','system'),
(2,'New Aid Request Received','Priyantha Jayawardena (Galle) applied for Chemotherapy Drug Support Grant.','request_update');

INSERT INTO `audit_logs` (`user_id`,`user_role`,`module`,`action`,`details`,`ip_address`,`severity`) VALUES
(4,'admin','SYSTEM_CONFIG','SEED_DATA','Demo data imported.','127.0.0.1','info');
