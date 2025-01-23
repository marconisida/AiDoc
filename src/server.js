import express from 'express';
import cors from 'cors';
import { createClient } from '@supabase/supabase-js';
import { config } from 'dotenv';
import { expressjwt } from 'express-jwt';
import jwt from 'jsonwebtoken';

// Load environment variables
config();

const app = express();
const port = process.env.PORT || 3000;

// Initialize Supabase client
const supabase = createClient(
  process.env.VITE_SUPABASE_URL,
  process.env.VITE_SUPABASE_ANON_KEY
);

// Middleware
app.use(cors());
app.use(express.json());

// JWT middleware for protected routes
const jwtCheck = expressjwt({
  secret: process.env.JWT_SECRET || 'your-secret-key',
  algorithms: ['HS256']
});

// Authentication endpoint
app.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;

  try {
    const { data: { user }, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) throw error;

    // Verify if user is an agency
    if (user.user_metadata?.role !== 'agency') {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Create JWT token
    const token = jwt.sign(
      { 
        sub: user.id,
        email: user.email,
        role: 'agency'
      },
      process.env.JWT_SECRET || 'your-secret-key',
      { expiresIn: '1d' }
    );

    res.json({ token });
  } catch (error) {
    res.status(401).json({ error: error.message });
  }
});

// Protected routes
app.use('/api', jwtCheck);

// Get all customers
app.get('/api/customers', async (req, res) => {
  try {
    const { data: users, error } = await supabase.rpc('get_users');
    
    if (error) throw error;

    // Filter out agency users
    const customers = users.filter(user => 
      user.raw_user_meta_data?.role !== 'agency'
    );

    res.json(customers);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get customer details with documents and progress
app.get('/api/customers/:id', async (req, res) => {
  const { id } = req.params;

  try {
    // Get user details
    const { data: user, error: userError } = await supabase.rpc('get_user', { user_id: id });
    if (userError) throw userError;

    // Get documents
    const { data: documents, error: docsError } = await supabase
      .from('documents')
      .select('*')
      .eq('user_id', id);
    if (docsError) throw docsError;

    // Get residency progress
    const { data: progress, error: progressError } = await supabase
      .from('residency_progress')
      .select(`
        *,
        residency_step_progress (
          step_id,
          status,
          notes,
          completed_at
        )
      `)
      .eq('user_id', id)
      .single();
    if (progressError && progressError.code !== 'PGRST116') throw progressError;

    res.json({
      user: user[0],
      documents,
      progress
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update customer progress
app.put('/api/customers/:id/progress', async (req, res) => {
  const { id } = req.params;
  const { stepId, status, notes } = req.body;

  try {
    const { data: progress, error: progressError } = await supabase
      .from('residency_progress')
      .select('id')
      .eq('user_id', id)
      .single();

    if (progressError) throw progressError;

    const { error: updateError } = await supabase
      .from('residency_step_progress')
      .update({
        status,
        notes,
        completed_at: status === 'completed' ? new Date().toISOString() : null
      })
      .eq('progress_id', progress.id)
      .eq('step_id', stepId);

    if (updateError) throw updateError;

    res.json({ message: 'Progress updated successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Add document notes
app.post('/api/documents/:id/notes', async (req, res) => {
  const { id } = req.params;
  const { notes } = req.body;

  try {
    const { error } = await supabase
      .from('documents')
      .update({ agency_notes: notes })
      .eq('id', id);

    if (error) throw error;

    res.json({ message: 'Notes added successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(port, () => {
  console.log(`Agency backend running on port ${port}`);
});