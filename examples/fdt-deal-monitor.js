// app.js
const { submitJob, getJobStatus, init } = require('./jobProcessor');
const express = require('express');
const app = express();
const multer  = require('multer');
const os = require('os');
const upload = multer({ dest: os.tmpdir() });

app.use(express.json());
const port = process.env.PORT || 3000;

// Endpoint to submit a job
// curl --form 'file=@"/Users/jay/Downloads/banana.jpeg"' localhost:3000/upload
app.post('/upload', upload.single('file'), async (req, res) => {  
  try {
    const jobData = req.body;
    const jobId = await submitJob(req.file);
    res.json({ jobId });
  } catch (error) {
    console.error('Error submitting job:', error);
    res.status(500).json({ error: 'Failed to submit job' });
  }
});

// Endpoint to get job status
// curl localhost:3000/job-status/1726301320606091
app.get('/job-status/:jobId', async (req, res) => {
  try {
    const jobId = req.params.jobId;
    const status = await getJobStatus(jobId);
    if (status) {
      res.json({ jobId, status });
    } else {
      res.status(404).json({ error: 'Job not found' });
    }
  } catch (error) {
    console.error('Error getting job status:', error);
    res.status(500).json({ error: 'Failed to get job status' });
  }
});

app.listen(port, async () => {
  console.log(`App listening on port ${port}`);
  init();
});

// // curl --form 'file=@"/Users/jay/Downloads/banana.jpeg"' localhost:3000/upload
