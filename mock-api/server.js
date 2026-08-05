const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const jsonServer = require('json-server');

const PORT = process.env.PORT || 3000;
const ROOT = __dirname;
const DB_PATH = path.join(ROOT, 'db', 'db.json');
const SEED_PATH = path.join(ROOT, 'db', 'db.seed.json');
const UPLOADS_DIR = path.join(ROOT, 'uploads');

if (!fs.existsSync(DB_PATH)) {
  fs.copyFileSync(SEED_PATH, DB_PATH);
}
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

const app = express();
const router = jsonServer.router(DB_PATH);
const middlewares = jsonServer.defaults({ noCors: true });

app.use(cors());
app.use(express.json({ limit: '8mb' }));
app.use(middlewares);
app.use('/uploads', express.static(UPLOADS_DIR));

const upload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, UPLOADS_DIR),
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname || '.jpg') || '.jpg';
      cb(null, `${Date.now()}-${crypto.randomBytes(4).toString('hex')}${ext}`);
    },
  }),
  limits: { fileSize: 8 * 1024 * 1024 },
});

/** @type {Map<string, { userId: string, exp: number }>} */
const tokens = new Map();

function readDb() {
  return JSON.parse(fs.readFileSync(DB_PATH, 'utf8'));
}

function writeDb(db) {
  fs.writeFileSync(DB_PATH, JSON.stringify(db, null, 2));
  router.db.setState(db);
  router.db.write();
}

function issueToken(userId) {
  const token = crypto.randomBytes(24).toString('hex');
  tokens.set(token, { userId, exp: Date.now() + 24 * 60 * 60 * 1000 });
  return token;
}

function authMiddleware(req, res, next) {
  const header = req.headers.authorization || '';
  const [, token] = header.split(' ');
  if (!token || !tokens.has(token)) {
    return res.status(401).json({ message: 'Não autorizado' });
  }
  const session = tokens.get(token);
  if (session.exp < Date.now()) {
    tokens.delete(token);
    return res.status(401).json({ message: 'Token expirado' });
  }
  const db = readDb();
  const user = db.users.find((u) => u.id === session.userId);
  if (!user) {
    return res.status(401).json({ message: 'Não autorizado' });
  }
  req.user = { id: user.id, name: user.name, email: user.email, role: user.role };
  next();
}

function publicUser(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
  };
}

app.get('/', (_req, res) => {
  res.json({
    name: 'Orbytis Desafio Flutter Mock API',
    docs: 'See CONTRATO_API.md',
    health: 'ok',
  });
});

app.post('/auth/login', (req, res) => {
  const email = String(req.body?.email || '').trim().toLowerCase();
  const password = String(req.body?.password || '');
  const db = readDb();
  const user = db.users.find(
    (u) => u.email.toLowerCase() === email && u.password === password,
  );
  if (!user) {
    return res.status(401).json({ message: 'Credenciais inválidas' });
  }
  const accessToken = issueToken(user.id);
  return res.json({
    accessToken,
    tokenType: 'Bearer',
    expiresIn: 86400,
    user: publicUser(user),
  });
});

app.get('/auth/me', authMiddleware, (req, res) => {
  res.json(req.user);
});

app.get('/work-orders', authMiddleware, (req, res) => {
  const db = readDb();
  let items = [...db.workOrders];
  if (req.query.status) {
    items = items.filter((w) => w.status === req.query.status);
  }
  res.json(items);
});

app.get('/work-orders/:id', authMiddleware, (req, res) => {
  const db = readDb();
  const item = db.workOrders.find((w) => w.id === req.params.id);
  if (!item) {
    return res.status(404).json({ message: 'Ordem de serviço não encontrada' });
  }
  res.json(item);
});

app.get('/work-orders/:id/form-schema', authMiddleware, (req, res) => {
  const db = readDb();
  const item = db.workOrders.find((w) => w.id === req.params.id);
  if (!item) {
    return res.status(404).json({ message: 'Ordem de serviço não encontrada' });
  }
  res.json({
    workOrderId: item.id,
    fields: [
      {
        key: 'observation',
        type: 'text',
        label: 'Observação',
        required: true,
        minLength: 10,
      },
      {
        key: 'condition',
        type: 'select',
        label: 'Condição do ativo',
        required: true,
        options: ['bom', 'regular', 'ruim', 'crítico'],
      },
      {
        key: 'photo',
        type: 'photo',
        label: 'Foto da evidência',
        required: true,
      },
      {
        key: 'location',
        type: 'location',
        label: 'Local da inspeção',
        required: true,
      },
    ],
  });
});

app.get('/inspections', authMiddleware, (req, res) => {
  const db = readDb();
  const items = db.inspections.filter((i) => i.createdBy === req.user.id);
  res.json(items);
});

function validateInspectionInput({
  clientId,
  workOrderId,
  observation,
  latitude,
  longitude,
  capturedAt,
  hasPhoto,
}) {
  const errors = {};
  if (!clientId) errors.clientId = ['obrigatório'];
  if (!workOrderId) errors.workOrderId = ['obrigatório'];
  if (!observation || String(observation).trim().length < 10) {
    errors.observation = ['mínimo de 10 caracteres'];
  }
  if (latitude === undefined || latitude === null || Number.isNaN(Number(latitude))) {
    errors.latitude = ['número inválido'];
  }
  if (longitude === undefined || longitude === null || Number.isNaN(Number(longitude))) {
    errors.longitude = ['número inválido'];
  }
  if (!capturedAt) errors.capturedAt = ['obrigatório'];
  if (!hasPhoto) errors.photo = ['arquivo obrigatório'];
  return errors;
}

function saveInspection({
  clientId,
  workOrderId,
  observation,
  condition,
  latitude,
  longitude,
  capturedAt,
  photoUrl,
  userId,
}) {
  const db = readDb();
  const existing = db.inspections.find((i) => i.clientId === clientId);
  if (existing) {
    return { status: 200, body: existing };
  }

  const workOrder = db.workOrders.find((w) => w.id === workOrderId);
  if (!workOrder) {
    return {
      status: 409,
      body: { message: 'workOrderId inexistente' },
    };
  }

  const inspection = {
    id: `insp_${Date.now()}`,
    clientId,
    workOrderId,
    observation: String(observation).trim(),
    condition: condition || null,
    photoUrl,
    latitude: Number(latitude),
    longitude: Number(longitude),
    capturedAt,
    syncedAt: new Date().toISOString(),
    createdBy: userId,
  };

  db.inspections.push(inspection);
  writeDb(db);
  return { status: 201, body: inspection };
}

app.post('/inspections', authMiddleware, upload.single('photo'), (req, res) => {
  const isMultipart = Boolean(req.is('multipart/form-data') || req.file);
  const body = req.body || {};

  let photoUrl = null;
  let hasPhoto = false;

  if (req.file) {
    hasPhoto = true;
    photoUrl = `/uploads/${req.file.filename}`;
  } else if (body.photoBase64) {
    hasPhoto = true;
    const buffer = Buffer.from(String(body.photoBase64), 'base64');
    const filename = `${Date.now()}-${crypto.randomBytes(4).toString('hex')}.jpg`;
    fs.writeFileSync(path.join(UPLOADS_DIR, filename), buffer);
    photoUrl = `/uploads/${filename}`;
  }

  const payload = {
    clientId: body.clientId,
    workOrderId: body.workOrderId,
    observation: body.observation,
    condition: body.condition,
    latitude: body.latitude,
    longitude: body.longitude,
    capturedAt: body.capturedAt,
    hasPhoto,
  };

  const errors = validateInspectionInput(payload);
  if (Object.keys(errors).length) {
    return res.status(400).json({ message: 'Payload inválido', errors });
  }

  const result = saveInspection({
    ...payload,
    photoUrl,
    userId: req.user.id,
  });

  // silence unused in simple setups
  void isMultipart;
  return res.status(result.status).json(result.body);
});

// Keep json-server router for eventual extras, but primary routes are above.
app.use(router);

app.listen(PORT, () => {
  console.log(`Mock API listening on http://localhost:${PORT}`);
});
