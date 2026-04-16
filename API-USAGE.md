# API Usage Guide - Ollama Production

## 🔗 Endpoints disponibles

**Base URL**: `https://ollama.bluevaloris.com`

### Authentification
Actuellement pas d'auth requis (restriction par domaine suffit), mais peut être ajoutée.

---

## 📝 Endpoints principaux

### 1. Generate Text
```http
POST /api/generate
```

**Exemple cURL:**
```bash
curl -X POST https://ollama.bluevaloris.com/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma2:2b",
    "prompt": "Quelle est la capital de la France?",
    "stream": false,
    "raw": false,
    "options": {
      "temperature": 0.7,
      "top_k": 40,
      "top_p": 0.9
    }
  }'
```

**Réponse:**
```json
{
  "model": "gemma2:2b",
  "created_at": "2024-04-16T12:34:56.789Z",
  "response": "La capital de la France est Paris.",
  "done": true,
  "context": [1, 306, 14910, ...],
  "total_duration": 2345678900,
  "load_duration": 123456789,
  "prompt_eval_count": 12,
  "prompt_eval_duration": 567890123,
  "eval_count": 8,
  "eval_duration": 1234567890
}
```

**Paramètres:**

| Param | Type | Description |
|-------|------|-------------|
| `model` | string | Modèle à utiliser (ex: `gemma2:2b`) |
| `prompt` | string | Texte d'entrée |
| `stream` | boolean | Streaming response si true |
| `raw` | boolean | Mode raw template |
| `template` | string | Template personnalisé |
| `context` | array | Contexte précédent (pour conversation) |
| `options` | object | Parameters tunning (voir ci-dessous) |

**Options availables:**

```json
"options": {
  "temperature": 0.7,      // 0.0-1.0: Créativité (plus bas = plus déterministe)
  "top_k": 40,             // Top-k sampling
  "top_p": 0.9,            // Nucleus sampling
  "repeat_last_n": 64,     // Derniers N tokens pour répétition
  "repeat_penalty": 1.1,   // Pénalité répétition
  "num_predict": 128,      // Nombre max tokens à générer
  "num_thread": 4          // Threads (override default)
}
```

---

### 2. Chat (Conversation)
```http
POST /api/chat
```

**Exemple:**
```bash
curl -X POST https://ollama.bluevaloris.com/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma2:2b",
    "messages": [
      {
        "role": "user",
        "content": "Bonjour, comment ça va?"
      }
    ],
    "stream": false
  }'
```

**Réponse:**
```json
{
  "model": "gemma2:2b",
  "created_at": "2024-04-16T12:34:56.789Z",
  "message": {
    "role": "assistant",
    "content": "Bonjour! Je vais bien, merci!"
  },
  "done": true,
  "total_duration": 2345678900,
  "load_duration": 123456789,
  "prompt_eval_count": 9,
  "prompt_eval_duration": 567890123,
  "eval_count": 6,
  "eval_duration": 1234567890
}
```

**Structure de conversation:**
```json
"messages": [
  {"role": "user", "content": "Hi"},
  {"role": "assistant", "content": "Hello!"},
  {"role": "user", "content": "How are you?"}
]
```

---

### 3. List Models
```http
GET /api/tags
```

**Exemple:**
```bash
curl https://ollama.bluevaloris.com/api/tags
```

**Réponse:**
```json
{
  "models": [
    {
      "name": "gemma2:2b",
      "modified_at": "2024-04-16T10:00:00Z",
      "size": 1600000000,
      "digest": "sha256:abc123..."
    }
  ]
}
```

---

### 4. Show Model Info
```http
GET /api/show
```

**Exemple:**
```bash
curl https://ollama.bluevaloris.com/api/show?name=gemma2:2b
```

**Réponse:**
```json
{
  "name": "gemma2:2b",
  "modified_at": "2024-04-16T10:00:00Z",
  "size": 1600000000,
  "digest": "sha256:abc123...",
  "details": {
    "format": "gguf",
    "family": "gemma2",
    "families": ["gemma2"],
    "parameter_size": "2B",
    "quantization_level": "Q4_0"
  }
}
```

---

### 5. Health Check
```http
GET /
```

**Exemple:**
```bash
curl https://ollama.bluevaloris.com/
```

---

## 💬 Exemples d'utilisation

### Exemple 1: Python
```python
import requests

url = "https://ollama.bluevaloris.com/api/generate"

payload = {
    "model": "gemma2:2b",
    "prompt": "Explique-moi comment fonctionne la photosynthèse",
    "stream": False
}

response = requests.post(url, json=payload)
print(response.json()["response"])
```

### Exemple 2: JavaScript/Node.js
```javascript
const axios = require('axios');

async function generateText() {
  const response = await axios.post('https://ollama.bluevaloris.com/api/generate', {
    model: 'gemma2:2b',
    prompt: 'Explique-moi comment fonctionne la photosynthèse',
    stream: false
  });
  
  console.log(response.data.response);
}

generateText();
```

### Exemple 3: Streaming Response
```bash
curl -X POST https://ollama.bluevaloris.com/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma2:2b",
    "prompt": "Bonjour",
    "stream": true
  }' | jq '.response'
```

Output (stream):
```
{"response":"Bo","done":false}
{"response":"njo","done":false}
{"response":"ur","done":false}
{"response":" ...","done":true}
```

### Exemple 4: Conversation Flow
```bash
# Message 1
curl -X POST https://ollama.bluevaloris.com/api/chat \
  -d '{
    "model": "gemma2:2b",
    "messages": [{"role": "user", "content": "Quel est ton nom?"}],
    "stream": false
  }' | jq '.message.content'

# Réponse: "Je suis un assistant IA basé sur Gemma 2."

# Message 2 (contexte maintenu)
curl -X POST https://ollama.bluevaloris.com/api/chat \
  -d '{
    "model": "gemma2:2b",
    "messages": [
      {"role": "user", "content": "Quel est ton nom?"},
      {"role": "assistant", "content": "Je suis un assistant IA basé sur Gemma 2."},
      {"role": "user", "content": "Aide-moi avec Python"}
    ],
    "stream": false
  }'
```

---

## ⚡ Performance Tips

1. **Warming up**: Le warmer service pingue toutes les 5 min, donc 1ère requête après être rapide
2. **Streaming**: Utilisez `stream: true` pour obtenir les tokens au fur et à mesure
3. **Context**: Pour conversation, réutilisez le contexte retourné
4. **Temperature**: 
   - Baissez pour réponses déterministes (0.1-0.3)
   - Augmentez pour créativité (0.8-1.0)

---

## 🔒 Rate Limiting

- Non configuré actuellement
- 4 requêtes parallèles maximum (OLLAMA_NUM_PARALLEL=4)

---

## ❌ Erreurs courantes

### 503 Service Unavailable
- Warmer service peut être en train de charger le modèle
- Attendre 5-10 secondes et réessayer

### 403 Forbidden
- Votre domaine n'est pas `*.bluevaloris.com`
- Vérifier l'en-tête `Host` ou proxy settings

### 404 Not Found
- Modèle n'existe pas
- Vérifier: `curl https://ollama.bluevaloris.com/api/tags`

### Invalid Request
- Paramètres JSON mal formés
- Vérifier Content-Type: `application/json`

---

## 📊 Monitoring

Pour vérifier la santé du service:
```bash
curl https://ollama.bluevaloris.com/api/tags
```

Response time = latence service (doit être <100ms)

---

## 🎯 Best Practices

1. **Sempre use HTTPS**: `https://` obligatoire en production
2. **Timeouts**: Set timeout 60+ secondes (génération peut être lente)
3. **Retry logic**: Implémenter retry avec exponential backoff
4. **Logging**: Logger les erreurs et latences pour monitoring
5. **Validation**: Vérifier que réponse contient `"done": true`
6. **Circuit breaker**: Désactiver/fallback si service down

---

## 🔗 Resources

- [Ollama Official API](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Gemma 2B Model](https://ollama.ai/library/gemma)
- [API Testing Tool](https://www.postman.com/) (Postman)

---

**API Version**: 1.0  
**Last Updated**: 2024  
**Support**: Contact DevOps team
