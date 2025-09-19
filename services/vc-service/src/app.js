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
