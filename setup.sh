#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check available memory
    AVAILABLE_MEMORY=$(docker system info --format '{{.MemTotal}}' 2>/dev/null || echo 0)
    if [[ $AVAILABLE_MEMORY -lt 8000000000 ]]; then
        log_warning "Less than 8GB memory available for Docker. System may run slowly."
        log_info "Consider increasing Docker memory allocation to 8GB+"
    fi
    
    log_success "Prerequisites check completed"
}

# Setup directories
setup_directories() {
    log_step "Creating directory structure..."
    
    directories=(
        "config/nginx"
        "config/mdms/tenant"
        "config/mdms/permit-system"
        "scripts/sql"
        "services/permit-service"
        "services/vc-service"
        "logs"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_info "Created directory: $dir"
        fi
    done
    
    log_success "Directory structure created"
}

# Create MDMS data files
setup_mdms_data() {
    log_step "Setting up MDMS data files..."
    
    # Create tenant configuration
    cat > config/mdms/tenant/tenants.json << 'EOF'
{
  "tenantId": "pg",
  "moduleName": "tenant",
  "tenants": [
    {
      "code": "pg.citya",
      "name": "City A",
      "description": "City A Municipal Corporation",
      "logoId": "https://citya.gov.in/logo.png",
      "imageId": "https://citya.gov.in/logo.png",
      "domainUrl": "https://citya.gov.in/",
      "type": "CITY",
      "twitterUrl": "https://twitter.com/citya_gov",
      "facebookUrl": "https://www.facebook.com/citya.gov",
      "emailId": "info@citya.gov.in",
      "OfficeTimings": {
        "Mon - Fri": "9.00 AM - 6.00 PM"
      },
      "city": {
        "name": "City A",
        "localName": "शहर ए",
        "districtCode": "DISTRICT_A",
        "districtName": "District A",
        "regionName": "Region A",
        "ulbGrade": "Municipal Corporation"
      },
      "address": "Municipal Corporation Building, City A - 110001",
      "contactNumber": "+91-11-12345678"
    }
  ]
}
EOF

    # Create PermitType master data
    cat > config/mdms/permit-system/PermitType.json << 'EOF'
{
  "tenantId": "pg.citya",
  "moduleName": "permit-system",
  "PermitType": [
    {
      "code": "FOOD_VENDOR",
      "name": "Food Vendor License",
      "localName": "खाद्य विक्रेता लाइसेंस",
      "description": "License for food stall/vendor operations",
      "category": "TRADE_LICENSE",
      "validityDays": 365,
      "renewalRequired": true,
      "fee": 500.00,
      "applicationFee": 50.00,
      "inspectionRequired": true,
      "maxProcessingDays": 7,
      "requiredDocuments": [
        "IDENTITY_PROOF",
        "ADDRESS_PROOF",
        "MEDICAL_CERTIFICATE"
      ],
      "active": true
    },
    {
      "code": "CONSTRUCTION_MINOR",
      "name": "Minor Construction Permit",
      "localName": "लघु निर्माण परमिट",
      "description": "Permit for minor construction work under 1000 sq ft",
      "category": "BUILDING_PERMIT",
      "validityDays": 180,
      "renewalRequired": false,
      "fee": 1000.00,
      "applicationFee": 100.00,
      "inspectionRequired": true,
      "maxProcessingDays": 15,
      "requiredDocuments": [
        "IDENTITY_PROOF",
        "PROPERTY_DOCUMENTS",
        "CONSTRUCTION_PLAN"
      ],
      "active": true
    }
  ]
}
EOF

    # Create BusinessService workflow configuration
    cat > config/mdms/permit-system/BusinessService.json << 'EOF'
{
  "tenantId": "pg.citya",
  "moduleName": "permit-system",
  "BusinessService": [
    {
      "businessService": "PERMIT_ISSUANCE",
      "business": "permit-services",
      "businessServiceSla": 432000000,
      "states": [
        {
          "sla": null,
          "state": "DRAFT",
          "applicationStatus": "DRAFT",
          "isStartState": true,
          "isTerminateState": false,
          "actions": [
            {
              "action": "SUBMIT",
              "nextState": "SUBMITTED",
              "roles": ["CITIZEN"]
            }
          ]
        },
        {
          "sla": 172800000,
          "state": "SUBMITTED",
          "applicationStatus": "UNDER_REVIEW",
          "isStartState": false,
          "isTerminateState": false,
          "actions": [
            {
              "action": "VERIFY_AND_FORWARD",
              "nextState": "APPROVED",
              "roles": ["PERMIT_VERIFIER"]
            },
            {
              "action": "REJECT",
              "nextState": "REJECTED",
              "roles": ["PERMIT_VERIFIER"]
            }
          ]
        },
        {
          "sla": null,
          "state": "APPROVED",
          "applicationStatus": "APPROVED",
          "isStartState": false,
          "isTerminateState": true,
          "actions": []
        },
        {
          "sla": null,
          "state": "REJECTED",
          "applicationStatus": "REJECTED",
          "isStartState": false,
          "isTerminateState": true,
          "actions": []
        }
      ]
    }
  ]
}
EOF

    log_success "MDMS data files created"
}

# Create custom service implementations
create_custom_services() {
    log_step "Creating custom service implementations..."
    
    # Create permit service
    mkdir -p services/permit-service/src
    
    cat > services/permit-service/package.json << 'EOF'
{
  "name": "permit-service",
  "version": "1.0.0",
  "description": "DIGIT Permit Service",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "dev": "nodemon src/app.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "body-parser": "^1.20.2",
    "uuid": "^9.0.0",
    "pg": "^8.8.0",
    "redis": "^4.5.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

    cat > services/permit-service/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

RUN addgroup -g 1001 -S nodejs
RUN adduser -S nestjs -u 1001

RUN chown -R nestjs:nodejs /app
USER nestjs

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/permit/health || exit 1

CMD ["npm", "start"]
EOF

    cat > services/permit-service/src/app.js << 'EOF'
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(cors());
app.use(bodyParser.json({ limit: '10mb' }));
app.use('/permit', express.Router());

// Health check
app.get('/permit/health', (req, res) => {
  res.status(200).json({
    status: 'UP',
    service: 'permit-service',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Create permit application
app.post('/permit/v1/_create', (req, res) => {
  const permitApplication = req.body.PermitApplication;
  
  const response = {
    ResponseInfo: { 
      apiId: req.body.RequestInfo?.apiId || 'permit-create',
      ver: '1.0',
      ts: Date.now(),
      status: 'successful'
    },
    PermitApplications: [{
      id: uuidv4(),
      applicationNumber: `PA-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 100000)).padStart(6, '0')}`,
      tenantId: permitApplication?.tenantId || 'pg.citya',
      status: 'DRAFT',
      createdTime: Date.now(),
      lastModifiedTime: Date.now(),
      ...permitApplication
    }]
  };
  
  res.status(200).json(response);
});

// Search permit applications
app.post('/permit/v1/_search', (req, res) => {
  const searchCriteria = req.body.PermitApplicationSearchCriteria;
  
  const response = {
    ResponseInfo: { 
      apiId: req.body.RequestInfo?.apiId || 'permit-search',
      ver: '1.0',
      ts: Date.now(),
      status: 'successful'
    },
    PermitApplications: [{
      id: uuidv4(),
      applicationNumber: 'PA-2024-000001',
      tenantId: searchCriteria?.tenantId || 'pg.citya',
      permitType: 'FOOD_VENDOR',
      applicantName: 'John Doe',
      applicantMobile: '9999999999',
      status: 'DRAFT',
      createdTime: Date.now(),
      lastModifiedTime: Date.now()
    }],
    TotalCount: 1
  };
  
  res.status(200).json(response);
});

// Update permit application
app.post('/permit/v1/_update', (req, res) => {
  const permitApplication = req.body.PermitApplication;
  
  const response = {
    ResponseInfo: { 
      apiId: req.body.RequestInfo?.apiId || 'permit-update',
      ver: '1.0',
      ts: Date.now(),
      status: 'successful'
    },
    PermitApplications: [{
      ...permitApplication,
      lastModifiedTime: Date.now()
    }]
  };
  
  res.status(200).json(response);
});

app.listen(PORT, () => {
  console.log(`Permit service running on port ${PORT}`);
});
EOF

    # Create VC service
    mkdir -p services/vc-service/src
    
    cat > services/vc-service/package.json << 'EOF'
{
  "name": "vc-service",
  "version": "1.0.0",
  "description": "DIGIT Verifiable Credentials Service",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "dev": "nodemon src/app.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "body-parser": "^1.20.2",
    "uuid": "^9.0.0",
    "qrcode": "^1.5.3",
    "crypto": "^1.0.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

    cat > services/vc-service/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

RUN addgroup -g 1001 -S nodejs
RUN adduser -S nestjs -u 1001
RUN mkdir -p /opt/vc/keys
RUN chown -R nestjs:nodejs /app /opt/vc/keys

USER nestjs

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/vc/health || exit 1

CMD ["npm", "start"]
EOF

    cat > services/vc-service/src/app.js << 'EOF'
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { v4: uuidv4 } = require('uuid');
const QRCode = require('qrcode');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(cors());
app.use(bodyParser.json({ limit: '10mb' }));
app.use('/vc', express.Router());

// Health check
app.get('/vc/health', (req, res) => {
  res.status(200).json({
    status: 'UP',
    service: 'vc-service',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Issue verifiable credential
app.post('/vc/v1/_issue', async (req, res) => {
  const credentialRequest = req.body.CredentialRequest;
  const vcId = `vc-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  
  const credential = {
    '@context': [
      'https://www.w3.org/2018/credentials/v1',
      'https://digit.org/credentials/permit/v1'
    ],
    id: vcId,
    type: ['VerifiableCredential', 'PermitCredential'],
    issuer: 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
    issuanceDate: new Date().toISOString(),
    credentialSubject: {
      id: credentialRequest?.holderDid || 'did:example:holder',
      ...credentialRequest?.credentialSubject
    },
    proof: {
      type: 'Ed25519Signature2020',
      created: new Date().toISOString(),
      verificationMethod: 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK#z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK',
      proofPurpose: 'assertionMethod',
      proofValue: crypto.randomBytes(32).toString('base64')
    }
  };
  
  const response = {
    ResponseInfo: { 
      apiId: req.body.RequestInfo?.apiId || 'vc-issue',
      ver: '1.0',
      ts: Date.now(),
      status: 'successful'
    },
    VerifiableCredential: credential
  };
  
  res.status(200).json(response);
});

// Verify credential
app.post('/vc/v1/_verify', (req, res) => {
  const verificationRequest = req.body.VerificationRequest;
  
  const response = {
    ResponseInfo: { 
      apiId: req.body.RequestInfo?.apiId || 'vc-verify',
      ver: '1.0',
      ts: Date.now(),
      status: 'successful'
    },
    VerificationResult: {
      isValid: true,
      vcId: verificationRequest?.vcId,
      verifiedAt: new Date().toISOString(),
      status: 'VALID',
      verificationMethod: 'cryptographic_proof'
    }
  };
  
  res.status(200).json(response);
});

// Generate QR code
app.post('/vc/v1/_generateQR', async (req, res) => {
  const qrRequest = req.body.QRRequest;
  const verifyUrl = `${process.env.QR_BASE_URL || 'http://localhost:8080/vc/verify'}/${qrRequest?.vcId || 'sample-vc-id'}`;
  
  try {
    const qrCodeImage = await QRCode.toDataURL(verifyUrl);
    
    const response = {
      ResponseInfo: { 
        apiId: req.body.RequestInfo?.apiId || 'vc-qr-generate',
        ver: '1.0',
        ts: Date.now(),
        status: 'successful'
      },
      QRCode: {
        qrCodeData: verifyUrl,
        qrCodeImage: qrCodeImage,
        expiryTime: Date.now() + (24 * 60 * 60 * 1000) // 24 hours
      }
    };
    
    res.status(200).json(response);
  } catch (error) {
    res.status(500).json({
      ResponseInfo: { 
        apiId: req.body.RequestInfo?.apiId || 'vc-qr-generate',
        ver: '1.0',
        ts: Date.now(),
        status: 'error'
      },
      error: 'Failed to generate QR code'
    });
  }
});

// QR code verification endpoint (for scanning)
app.get('/vc/verify/:vcId', (req, res) => {
  const vcId = req.params.vcId;
  
  res.status(200).json({
    vcId: vcId,
    status: 'VALID',
    verifiedAt: new Date().toISOString(),
    permitDetails: {
      permitType: 'FOOD_VENDOR',
      holderName: 'John Doe',
      businessName: 'Johns Food Stall',
      expiryDate: '2025-01-15'
    }
  });
});

app.listen(PORT, () => {
  console.log(`VC service running on port ${PORT}`);
});
EOF

    log_success "Custom service implementations created"
}

# Make scripts executable
make_scripts_executable() {
    log_step "Making scripts executable..."
    chmod +x scripts/*.sh 2>/dev/null || true
    log_success "Scripts are now executable"
}

# Show completion message
show_completion_message() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  DIGIT OSS Setup Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${CYAN}Next steps:${NC}"
    echo -e "  1. ${YELLOW}./scripts/start.sh infrastructure${NC} - Start infrastructure services"
    echo -e "  2. ${YELLOW}Wait 2-3 minutes${NC} for infrastructure to be ready"
    echo -e "  3. ${YELLOW}./scripts/start.sh core${NC} - Start core DIGIT services"
    echo -e "  4. ${YELLOW}Wait 3-4 minutes${NC} for core services to start"
    echo -e "  5. ${YELLOW}./scripts/start.sh custom${NC} - Start custom services"
    echo -e "  6. ${YELLOW}./scripts/health-check.sh${NC} - Verify all services"
    echo
    echo -e "${CYAN}Quick start (all at once):${NC}"
    echo -e "  ${YELLOW}./scripts/start.sh all${NC}"
    echo
    echo -e "${CYAN}Testing:${NC}"
    echo -e "  Import ${BLUE}DIGIT-OSS-Local-Tests.postman_collection.json${NC} into Postman"
    echo -e "  Set base_url variable to: ${BLUE}http://localhost:8080${NC}"
    echo
    echo -e "${CYAN}Key URLs after startup:${NC}"
    echo -e "  API Gateway: ${BLUE}http://localhost:8080${NC}"
    echo -e "  User Service: ${BLUE}http://localhost:8080/user${NC}"
    echo -e "  Permit Service: ${BLUE}http://localhost:8080/permit${NC}"
    echo -e "  VC Service: ${BLUE}http://localhost:8080/vc${NC}"
    echo
}

# Main execution
main() {
    echo -e "${CYAN}=====================================${NC}"
    echo -e "${CYAN}  DIGIT OSS Local Setup${NC}"
    echo -e "${CYAN}=====================================${NC}"
    echo
    
    check_prerequisites
    setup_directories
    setup_mdms_data
    create_custom_services
    make_scripts_executable
    
    show_completion_message
}

# Run main function
main