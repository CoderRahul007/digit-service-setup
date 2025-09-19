-- DIGIT OSS Database Initialization Script
-- This script sets up the database schema and initial data for DIGIT services

-- Ensure base schemas exist
CREATE SCHEMA IF NOT EXISTS egov_user;
CREATE SCHEMA IF NOT EXISTS egov_access;
CREATE SCHEMA IF NOT EXISTS workflow;
CREATE SCHEMA IF NOT EXISTS billing;
CREATE SCHEMA IF NOT EXISTS collection;
CREATE SCHEMA IF NOT EXISTS filestore;
CREATE SCHEMA IF NOT EXISTS idgen;
CREATE SCHEMA IF NOT EXISTS mdms;

-- Existing schema/data setup from your file
CREATE SCHEMA IF NOT EXISTS permit_schema;
CREATE SCHEMA IF NOT EXISTS vc_schema;



-- Create additional databases if they don't exist
SELECT 'CREATE DATABASE egov_ms' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'egov_ms')\gexec
SELECT 'CREATE DATABASE devops' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'devops')\gexec
SELECT 'CREATE DATABASE ukd' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ukd')\gexec

-- Create egov user if not exists
DO $do$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE  rolname = 'egov') THEN
      CREATE USER egov WITH PASSWORD 'egov123';
   END IF;
END $do$;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE egov TO egov;
GRANT ALL PRIVILEGES ON DATABASE egov_ms TO egov;
GRANT ALL PRIVILEGES ON DATABASE devops TO egov;
GRANT ALL PRIVILEGES ON DATABASE ukd TO egov;

-- Connect to main egov database
\c egov;

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create schemas
CREATE SCHEMA IF NOT EXISTS permit_schema;
CREATE SCHEMA IF NOT EXISTS vc_schema;

-- DIGIT Core User Management Tables
CREATE TABLE IF NOT EXISTS eg_user (
    id BIGSERIAL PRIMARY KEY,
    uuid VARCHAR(128) UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    username VARCHAR(180) UNIQUE,
    password VARCHAR(100),
    salutation VARCHAR(5),
    name VARCHAR(100) NOT NULL,
    gender VARCHAR(8),
    mobilenumber VARCHAR(50),
    emailid VARCHAR(300),
    altcontactnumber VARCHAR(50),
    pan VARCHAR(10),
    aadharnumber VARCHAR(20),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    type VARCHAR(50) NOT NULL DEFAULT 'CITIZEN',
    accountlocked BOOLEAN DEFAULT FALSE,
    accountlockdate BIGINT,
    bloodgroup VARCHAR(3),
    photo VARCHAR(36),
    identificationmark VARCHAR(300),
    signature VARCHAR(36),
    locale VARCHAR(10) DEFAULT 'en_IN',
    createdby BIGINT NOT NULL,
    createddate BIGINT NOT NULL,
    lastmodifiedby BIGINT,
    lastmodifieddate BIGINT,
    tenantid VARCHAR(256) NOT NULL,
    CONSTRAINT uk_eg_user_username_tenantid UNIQUE (username, tenantid)
);

CREATE TABLE IF NOT EXISTS eg_role (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL,
    description VARCHAR(250),
    createdby BIGINT NOT NULL,
    createddate BIGINT NOT NULL,
    lastmodifiedby BIGINT,
    lastmodifieddate BIGINT,
    tenantid VARCHAR(256) NOT NULL,
    CONSTRAINT uk_eg_role_code_tenantid UNIQUE (code, tenantid)
);

CREATE TABLE IF NOT EXISTS eg_userrole (
    id BIGSERIAL PRIMARY KEY,
    rolecode VARCHAR(50) NOT NULL,
    userid BIGINT NOT NULL,
    tenantid VARCHAR(256) NOT NULL,
    CONSTRAINT fk_eg_userrole_userid FOREIGN KEY (userid) REFERENCES eg_user(id),
    CONSTRAINT uk_eg_userrole_userid_rolecode_tenantid UNIQUE (userid, rolecode, tenantid)
);

-- Workflow Tables
CREATE TABLE IF NOT EXISTS eg_wf_businessservice_v2 (
    id VARCHAR(128) PRIMARY KEY,
    tenantid VARCHAR(128) NOT NULL,
    business VARCHAR(128) NOT NULL,
    businessservice VARCHAR(128) NOT NULL,
    businessservicesla BIGINT,
    createdby VARCHAR(128),
    createdtime BIGINT,
    lastmodifiedby VARCHAR(128),
    lastmodifiedtime BIGINT
);

CREATE TABLE IF NOT EXISTS eg_wf_state_v2 (
    id VARCHAR(128) PRIMARY KEY,
    tenantid VARCHAR(128) NOT NULL,
    businessserviceid VARCHAR(128) NOT NULL,
    sla BIGINT,
    state VARCHAR(50) NOT NULL,
    applicationstatus VARCHAR(50),
    docuploadrequired BOOLEAN,
    isstartstateuploadrequired BOOLEAN,
    isterminalstate BOOLEAN,
    isstateupdatable BOOLEAN,
    createdby VARCHAR(128),
    createdtime BIGINT,
    lastmodifiedby VARCHAR(128),
    lastmodifiedtime BIGINT
);

-- Billing Tables
CREATE TABLE IF NOT EXISTS egbs_billdetial_v1 (
    id VARCHAR(128) PRIMARY KEY,
    tenantid VARCHAR(128) NOT NULL,
    billid VARCHAR(128) NOT NULL,
    demandid VARCHAR(128),
    fromperiod BIGINT,
    toperiod BIGINT,
    billnumber VARCHAR(128),
    billdate BIGINT,
    consumercode VARCHAR(128),
    consumertype VARCHAR(128),
    businessservice VARCHAR(128),
    totalamount NUMERIC(12,2) DEFAULT 0,
    collectedamount NUMERIC(12,2) DEFAULT 0,
    status VARCHAR(128),
    createdby VARCHAR(128),
    createdtime BIGINT,
    lastmodifiedby VARCHAR(128),
    lastmodifiedtime BIGINT
);

-- Filestore Tables
CREATE TABLE IF NOT EXISTS eg_filestoremap (
    id VARCHAR(128) PRIMARY KEY,
    fileStoreid VARCHAR(128) NOT NULL,
    filename VARCHAR(300) NOT NULL,
    contenttype VARCHAR(50),
    path VARCHAR(500),
    createdby VARCHAR(128),
    createdtime BIGINT,
    lastmodifiedby VARCHAR(128),
    lastmodifiedtime BIGINT,
    tenantid VARCHAR(256) NOT NULL
);

-- IDGEN Tables
CREATE TABLE IF NOT EXISTS eg_idgen_sequence (
    id VARCHAR(128) PRIMARY KEY,
    tenantid VARCHAR(128) NOT NULL,
    idname VARCHAR(128) NOT NULL,
    format VARCHAR(128) NOT NULL,
    currentvalue BIGINT NOT NULL DEFAULT 0
);

-- Permit System Tables (Custom)
CREATE TABLE IF NOT EXISTS permit_schema.permit_application (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    application_number VARCHAR(64) UNIQUE NOT NULL,
    tenant_id VARCHAR(128) NOT NULL,
    permit_type VARCHAR(64) NOT NULL,
    applicant_id UUID,
    applicant_name VARCHAR(200) NOT NULL,
    applicant_mobile VARCHAR(15) NOT NULL,
    applicant_email VARCHAR(100),
    business_name VARCHAR(300),
    business_address TEXT,
    business_location_lat DECIMAL(10, 8),
    business_location_lng DECIMAL(11, 8),
    application_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(32) DEFAULT 'DRAFT',
    workflow_code VARCHAR(64) DEFAULT 'PERMIT_ISSUANCE',
    workflow_state VARCHAR(32) DEFAULT 'DRAFT',
    total_amount DECIMAL(12,2) DEFAULT 0,
    application_fee DECIMAL(12,2) DEFAULT 0,
    permit_fee DECIMAL(12,2) DEFAULT 0,
    permit_valid_from DATE,
    permit_valid_to DATE,
    comments TEXT,
    rejection_reason TEXT,
    approval_comments TEXT,
    created_by UUID,
    created_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified_by UUID,
    last_modified_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    additional_details JSONB DEFAULT '{}'::jsonb
);

-- Verifiable Credentials Tables (Custom)
CREATE TABLE IF NOT EXISTS vc_schema.verifiable_credential (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    permit_id UUID NOT NULL,
    vc_id VARCHAR(256) UNIQUE NOT NULL,
    did VARCHAR(256),
    credential_json JSONB NOT NULL,
    credential_hash VARCHAR(128),
    qr_code TEXT,
    qr_code_data TEXT,
    issued_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expiry_date TIMESTAMP,
    is_revoked BOOLEAN DEFAULT FALSE,
    revocation_reason VARCHAR(500),
    revocation_date TIMESTAMP,
    created_by UUID,
    created_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tenant_id VARCHAR(128) NOT NULL,
    CONSTRAINT fk_vc_permit_id FOREIGN KEY (permit_id) REFERENCES permit_schema.permit_application(id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_eg_user_username ON eg_user(username);
CREATE INDEX IF NOT EXISTS idx_eg_user_mobilenumber ON eg_user(mobilenumber);
CREATE INDEX IF NOT EXISTS idx_eg_user_tenantid ON eg_user(tenantid);
CREATE INDEX IF NOT EXISTS idx_permit_application_tenant_id ON permit_schema.permit_application(tenant_id);
CREATE INDEX IF NOT EXISTS idx_permit_application_status ON permit_schema.permit_application(status);
CREATE INDEX IF NOT EXISTS idx_permit_application_applicant_mobile ON permit_schema.permit_application(applicant_mobile);
CREATE INDEX IF NOT EXISTS idx_vc_permit_id ON vc_schema.verifiable_credential(permit_id);
CREATE INDEX IF NOT EXISTS idx_vc_vc_id ON vc_schema.verifiable_credential(vc_id);

-- Insert initial data
-- Insert system user
INSERT INTO eg_user (uuid, username, name, mobilenumber, emailid, active, type, createdby, createddate, tenantid) 
VALUES ('11e95c28-9e0c-4a1d-b4b5-1234567890ab', 'system', 'System User', '0000000000', 'system@digit.org', true, 'SYSTEM', 1, EXTRACT(EPOCH FROM NOW()) * 1000, 'pg.citya')
ON CONFLICT (uuid) DO NOTHING;

-- Insert sample users
INSERT INTO eg_user (uuid, username, name, mobilenumber, emailid, active, type, createdby, createddate, tenantid) 
VALUES 
('11e95c28-9e0c-4a1d-b4b5-1234567890cd', 'admin', 'System Administrator', '9876543210', 'admin@digit.org', true, 'EMPLOYEE', 1, EXTRACT(EPOCH FROM NOW()) * 1000, 'pg.citya'),
('11e95c28-9e0c-4a1d-b4b5-1234567890ef', 'citizen1', 'John Doe', '9876543211', 'john@example.com', true, 'CITIZEN', 1, EXTRACT(EPOCH FROM NOW()) * 1000, 'pg.citya'),
('11e95c28-9e0c-4a1d-b4b5-1234567890gh', 'officer1', 'Jane Smith', '9876543212', 'jane@citya.gov.in', true, 'EMPLOYEE', 1, EXTRACT(EPOCH FROM NOW()) * 1000, 'pg.citya'),
('11e95c28-9e0c-4a1d-b4b5-1234567890ij', 'verifier1', 'Mike Wilson', '9876543213', 'mike@citya.gov.in', true, 'EMPLOYEE', 1, EXTRACT(EPOCH FROM NOW()) * 1000, 'pg.citya')
ON CONFLICT (uuid) DO NOTHING;

-- Insert roles
INSERT INTO eg_role (name, code, description, createdby, createddate, tenantid) 
VALUES 
('Citizen', 'CITIZEN', 'Citizen Role for permit applications', 1, EXTRACT(EPOCH FROM NOW()) * 1000, 'pg.citya'),
('Permit Verifier', 'PERMIT_VERIFIER', 'Officer role for permit verification', 1, EXTRACT(EPOCH FROM NOW()) * 1000, 'pg.citya'),
('Permit Approver', 'PERMIT_APPROVER', 'Officer role for permit approval', 1, EXTRACT(EPOCH FROM NOW()) * 1000, 'pg.citya'),
('System Admin', 'SYSTEM_ADMIN', 'System Administrator Role', 1, EXTRACT(EPOCH FROM NOW()) * 1000, 'pg.citya')
ON CONFLICT (code, tenantid) DO NOTHING;

-- Assign roles to users
INSERT INTO eg_userrole (rolecode, userid, tenantid)
SELECT 'SYSTEM_ADMIN', id, 'pg.citya' FROM eg_user WHERE username = 'admin' AND tenantid = 'pg.citya'
ON CONFLICT (userid, rolecode, tenantid) DO NOTHING;

INSERT INTO eg_userrole (rolecode, userid, tenantid)
SELECT 'CITIZEN', id, 'pg.citya' FROM eg_user WHERE username = 'citizen1' AND tenantid = 'pg.citya'
ON CONFLICT (userid, rolecode, tenantid) DO NOTHING;

-- Insert ID generation sequences
INSERT INTO eg_idgen_sequence (id, tenantid, idname, format, currentvalue)
VALUES 
('1', 'pg.citya', 'permit.number', 'PA-[fy:yyyy-yy]-[SEQ_PERMIT_NUMBER]', 1),
('2', 'pg.citya', 'vc.number', 'VC-[fy:yyyy-yy]-[SEQ_VC_NUMBER]', 1)
ON CONFLICT (id) DO NOTHING;

-- Grant all necessary permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO egov;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO egov;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA permit_schema TO egov;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA permit_schema TO egov;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA vc_schema TO egov;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA vc_schema TO egov;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO egov;
ALTER DEFAULT PRIVILEGES IN SCHEMA permit_schema GRANT ALL ON TABLES TO egov;
ALTER DEFAULT PRIVILEGES IN SCHEMA vc_schema GRANT ALL ON TABLES TO egov;

COMMIT;