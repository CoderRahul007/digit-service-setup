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
