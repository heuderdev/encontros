-- Diario privado de encontros | Micro-SaaS single-owner
-- MySQL 8.0.16+ / InnoDB / utf8mb4
-- Execute em um banco vazio configurado no .env do Laravel.
-- Este arquivo nao inclui CREATE DATABASE nem apaga tabelas existentes.
-- Nao execute migrations que criem novamente estas mesmas tabelas.
-- Tenant = usuario autenticado (user_id). FKs compostas evitam referencias
-- entre contas diferentes; o Laravel ainda deve aplicar user_id = auth()->id()
-- em TODA leitura, escrita, edicao e exclusao.
-- Campos *_encrypted guardam ciphertext gerado pela aplicacao, nunca texto puro.

CREATE TABLE users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    public_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(255) NOT NULL,
    email_verified_at TIMESTAMP NULL DEFAULT NULL,
    password VARCHAR(255) NOT NULL,
    remember_token VARCHAR(100) NULL,
    timezone VARCHAR(64) NOT NULL DEFAULT 'America/Sao_Paulo',
    status ENUM('active','suspended') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_public_id (public_id),
    UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE password_reset_tokens (
    email VARCHAR(255) NOT NULL,
    token VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE sessions (
    id VARCHAR(255) NOT NULL,
    user_id BIGINT UNSIGNED NULL,
    ip_address VARCHAR(45) NULL,
    user_agent TEXT NULL,
    payload LONGTEXT NOT NULL,
    last_activity INT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    KEY idx_sessions_user (user_id),
    KEY idx_sessions_last_activity (last_activity),
    CONSTRAINT fk_sessions_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE jobs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    queue VARCHAR(255) NOT NULL,
    payload LONGTEXT NOT NULL,
    attempts TINYINT UNSIGNED NOT NULL,
    reserved_at INT UNSIGNED NULL,
    available_at INT UNSIGNED NOT NULL,
    created_at INT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    KEY idx_jobs_queue (queue)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE failed_jobs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid VARCHAR(255) NOT NULL,
    connection TEXT NOT NULL,
    queue TEXT NOT NULL,
    payload LONGTEXT NOT NULL,
    exception LONGTEXT NOT NULL,
    failed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_failed_jobs_uuid (uuid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE job_batches (
    id VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    total_jobs INT NOT NULL,
    pending_jobs INT NOT NULL,
    failed_jobs INT NOT NULL,
    failed_job_ids LONGTEXT NOT NULL,
    options MEDIUMTEXT NULL,
    cancelled_at INT NULL,
    created_at INT NOT NULL,
    finished_at INT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE partners (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    public_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    display_name_encrypted TEXT NOT NULL,
    phone_encrypted TEXT NULL,
    address_encrypted TEXT NULL,
    photo_path_encrypted TEXT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_partners_user_id (user_id,id),
    UNIQUE KEY uq_partners_user_public (user_id,public_id),
    KEY idx_partners_user_created (user_id,created_at),
    CONSTRAINT fk_partners_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE encounters (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    partner_id BIGINT UNSIGNED NOT NULL,
    public_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    occurred_on DATE NULL,
    date_status ENUM('known','unknown') NOT NULL DEFAULT 'known',
    started_at TIME NULL,
    ended_at TIME NULL,
    note_encrypted LONGTEXT NULL,
    source ENUM('manual','import') NOT NULL DEFAULT 'manual',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_encounters_user_id (user_id,id),
    UNIQUE KEY uq_encounters_user_partner_id (user_id,partner_id,id),
    UNIQUE KEY uq_encounters_user_public (user_id,public_id),
    KEY idx_encounters_user_date (user_id,occurred_on),
    KEY idx_encounters_user_partner_date (user_id,partner_id,occurred_on),
    CONSTRAINT fk_encounters_partner FOREIGN KEY (user_id,partner_id)
        REFERENCES partners(user_id,id) ON DELETE CASCADE,
    CONSTRAINT chk_encounters_date CHECK (
        (date_status='known' AND occurred_on IS NOT NULL) OR
        (date_status='unknown' AND occurred_on IS NULL AND source='import')
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE encounter_timeline_items (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    encounter_id BIGINT UNSIGNED NOT NULL,
    item_type ENUM('conversation','kiss','note','other') NOT NULL,
    happened_at TIME NULL,
    content_encrypted LONGTEXT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_timeline_user_encounter (user_id,encounter_id),
    CONSTRAINT fk_timeline_encounter FOREIGN KEY (user_id,encounter_id)
        REFERENCES encounters(user_id,id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Uma linha por ocorrencia sexual. O detalhamento por pratica fica em
-- intimacy_event_practices. protection_status e um resumo opcional e nao deve
-- ser a fonte de verdade quando houver praticas com protecoes diferentes.
CREATE TABLE intimacy_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    partner_id BIGINT UNSIGNED NOT NULL,
    encounter_id BIGINT UNSIGNED NOT NULL,
    occurred_at TIME NULL,
    note_encrypted LONGTEXT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_events_user_id (user_id,id),
    KEY idx_events_user_partner (user_id,partner_id),
    KEY idx_events_user_encounter (user_id,encounter_id),
    KEY idx_events_user_partner_encounter (user_id,partner_id,encounter_id),
    CONSTRAINT fk_events_encounter FOREIGN KEY (user_id,partner_id,encounter_id)
        REFERENCES encounters(user_id,partner_id,id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Uma ocorrencia pode ter varias praticas (oral, vaginal, anal e outras).
-- Uma linha por pratica executada; a protecao e especifica daquela pratica.
CREATE TABLE intimacy_event_practices (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    intimacy_event_id BIGINT UNSIGNED NOT NULL,
    practice_type ENUM('oral','vaginal','anal','beijo','other') NOT NULL,
    protection_status ENUM(
        'used',
        'not_used',
        'broke',
        'slipped',
        'unknown',
        'not_applicable'
    ) NOT NULL DEFAULT 'unknown',
    note_encrypted LONGTEXT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_event_practices_user_id (user_id,id),
    KEY idx_event_practices_user_event (user_id,intimacy_event_id),
    KEY idx_event_practices_user_type_status (user_id,practice_type,protection_status),
    CONSTRAINT fk_event_practices_event FOREIGN KEY (user_id,intimacy_event_id)
        REFERENCES intimacy_events(user_id,id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Detalhes adicionais vinculados a pratica. Ex.: tipo de barreira ou observacao
-- sobre uma falha. Nao usar para criar outro status concorrente ao da pratica.
CREATE TABLE protection_records (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    intimacy_event_practice_id BIGINT UNSIGNED NOT NULL,
    kind ENUM('barrier','contraception','other') NOT NULL,
    detail_encrypted LONGTEXT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_protection_user_practice (user_id,intimacy_event_practice_id),
    CONSTRAINT fk_protection_practice FOREIGN KEY (user_id,intimacy_event_practice_id)
        REFERENCES intimacy_event_practices(user_id,id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE partner_notes (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    partner_id BIGINT UNSIGNED NOT NULL,
    category ENUM('general','communication','wellbeing','other') NOT NULL DEFAULT 'general',
    body_encrypted LONGTEXT NOT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_partner_notes_user_partner (user_id,partner_id),
    CONSTRAINT fk_partner_notes_partner FOREIGN KEY (user_id,partner_id)
        REFERENCES partners(user_id,id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE partner_preferences (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    partner_id BIGINT UNSIGNED NOT NULL,
    description_encrypted LONGTEXT NOT NULL,
    source ENUM('shared','personal_note') NOT NULL DEFAULT 'shared',
    recorded_on DATE NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_preferences_user_partner (user_id,partner_id),
    CONSTRAINT fk_preferences_partner FOREIGN KEY (user_id,partner_id)
        REFERENCES partners(user_id,id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE partner_boundaries (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    partner_id BIGINT UNSIGNED NOT NULL,
    description_encrypted LONGTEXT NOT NULL,
    source ENUM('shared','personal_note') NOT NULL DEFAULT 'shared',
    recorded_on DATE NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_boundaries_user_partner (user_id,partner_id),
    CONSTRAINT fk_boundaries_partner FOREIGN KEY (user_id,partner_id)
        REFERENCES partners(user_id,id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE health_followups (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    partner_id BIGINT UNSIGNED NULL,
    encounter_id BIGINT UNSIGNED NULL,
    kind ENUM('test','appointment','reminder','other') NOT NULL,
    scheduled_on DATE NULL,
    completed_on DATE NULL,
    status ENUM('pending','completed','cancelled') NOT NULL DEFAULT 'pending',
    note_encrypted LONGTEXT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_followups_user_schedule (user_id,status,scheduled_on),
    KEY idx_followups_user_partner (user_id,partner_id),
    KEY idx_followups_user_encounter (user_id,encounter_id),
    CONSTRAINT fk_followups_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_followups_partner FOREIGN KEY (user_id,partner_id)
        REFERENCES partners(user_id,id) ON DELETE CASCADE,
    CONSTRAINT fk_followups_encounter FOREIGN KEY (user_id,encounter_id)
        REFERENCES encounters(user_id,id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE reminders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    partner_id BIGINT UNSIGNED NULL,
    encounter_id BIGINT UNSIGNED NULL,
    due_at DATETIME NOT NULL,
    status ENUM('pending','done','cancelled') NOT NULL DEFAULT 'pending',
    title_encrypted TEXT NOT NULL,
    note_encrypted LONGTEXT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_reminders_user_due (user_id,status,due_at),
    KEY idx_reminders_user_partner (user_id,partner_id),
    KEY idx_reminders_user_encounter (user_id,encounter_id),
    CONSTRAINT fk_reminders_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_reminders_partner FOREIGN KEY (user_id,partner_id)
        REFERENCES partners(user_id,id) ON DELETE CASCADE,
    CONSTRAINT fk_reminders_encounter FOREIGN KEY (user_id,encounter_id)
        REFERENCES encounters(user_id,id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE attachments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    partner_id BIGINT UNSIGNED NULL,
    encounter_id BIGINT UNSIGNED NULL,
    disk VARCHAR(64) NOT NULL DEFAULT 'private',
    path_encrypted TEXT NOT NULL,
    original_name_encrypted TEXT NULL,
    mime_type VARCHAR(120) NULL,
    byte_size BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_attachments_user_partner (user_id,partner_id),
    KEY idx_attachments_user_encounter (user_id,encounter_id),
    CONSTRAINT fk_attachments_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_attachments_partner FOREIGN KEY (user_id,partner_id)
        REFERENCES partners(user_id,id) ON DELETE CASCADE,
    CONSTRAINT fk_attachments_encounter FOREIGN KEY (user_id,encounter_id)
        REFERENCES encounters(user_id,id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE consent_audit_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    action ENUM('accepted','revoked','updated') NOT NULL,
    purpose VARCHAR(100) NOT NULL,
    policy_version VARCHAR(32) NOT NULL,
    occurred_at DATETIME NOT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_consent_user_date (user_id,occurred_at),
    CONSTRAINT fk_consent_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE subscriptions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    provider VARCHAR(50) NOT NULL,
    provider_customer_id VARCHAR(191) NULL,
    provider_subscription_id VARCHAR(191) NULL,
    plan_code VARCHAR(60) NOT NULL,
    status ENUM('trialing','active','past_due','cancelled','expired') NOT NULL,
    trial_ends_at DATETIME NULL,
    current_period_ends_at DATETIME NULL,
    cancelled_at DATETIME NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_subscriptions_user_status (user_id,status),
    UNIQUE KEY uq_subscriptions_provider_sub (provider,provider_subscription_id),
    CONSTRAINT fk_subscriptions_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE billing_webhook_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    provider VARCHAR(50) NOT NULL,
    provider_event_id VARCHAR(191) NOT NULL,
    event_type VARCHAR(120) NOT NULL,
    processing_status ENUM('pending','processed','failed') NOT NULL DEFAULT 'pending',
    processed_at DATETIME NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_billing_webhook_event (provider,provider_event_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE import_batches (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    status ENUM('draft','review','completed','cancelled') NOT NULL DEFAULT 'draft',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_import_batches_user_id (user_id,id),
    KEY idx_import_batches_user_status (user_id,status),
    CONSTRAINT fk_import_batches_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE import_rows (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    import_batch_id BIGINT UNSIGNED NOT NULL,
    row_number INT UNSIGNED NOT NULL,
    raw_encrypted LONGTEXT NOT NULL,
    status ENUM('pending','invalid','imported') NOT NULL DEFAULT 'pending',
    validation_errors_encrypted LONGTEXT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_import_rows_batch_number (user_id,import_batch_id,row_number),
    KEY idx_import_rows_user_status (user_id,status),
    CONSTRAINT fk_import_rows_batch FOREIGN KEY (user_id,import_batch_id)
        REFERENCES import_batches(user_id,id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Regras de implementacao:
-- 1. Gerar public_id no Laravel antes de inserir users, partners e encounters.
-- 2. Para criar um encontro: inserir encounters -> intimacy_events ->
--    intimacy_event_practices -> protection_records, tudo em DB::transaction().
-- 3. Para consultas de pratica/protecao, intimacy_event_practices e a fonte de
--    verdade. intimacy_events.protection_status deve ser tratado como resumo
--    legado/rapido e atualizado pelo service se voce optar por exibi-lo.
-- 4. Soft deletes nao disparam ON DELETE CASCADE; filtros devem aplicar
--    deleted_at IS NULL quando apropriado.
-- 5. health_followups, reminders e attachments permitem partner_id e encounter_id
--    simultaneamente. O service deve validar encounter.partner_id = partner_id.
-- 6. Excluir um user em cascata remove linhas no banco, mas nao remove arquivos
--    no storage, backups nem dados fora da base. Implemente rotina de exclusao.
