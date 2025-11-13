'use strict'

require('dotenv').config()

const { App, ExpressReceiver } = require('@slack/bolt')
const express = require('express')
const cors = require('cors')

const requiredEnv = ['SLACK_SIGNING_SECRET', 'SLACK_BOT_TOKEN']
const missing = requiredEnv.filter((k) => !process.env[k] || process.env[k].trim() === '')
if (missing.length > 0) {
  console.error(`Missing required environment variables: ${missing.join(', ')}`)
  process.exit(1)
}

const port = process.env.PORT || 3000

// Create an ExpressReceiver to host Slack endpoints and custom API routes
const receiver = new ExpressReceiver({
  signingSecret: process.env.SLACK_SIGNING_SECRET,
})

// Access the underlying Express app to add middlewares and routes
const expressApp = receiver.app
expressApp.use(cors())
expressApp.use(express.json())

// Create the Slack Bolt app
const app = new App({
  token: process.env.SLACK_BOT_TOKEN,
  receiver,
})

// Respond when the app is mentioned: requires 'app_mentions:read' and 'chat:write' scopes
app.event('app_mention', async ({ event, say }) => {
  const userTag = `<@${event.user}>`
  await say(`${userTag} thanks for the mention!`)
})

// Basic health route
expressApp.get('/health', (req, res) => {
  res.status(200).send('ok')
})

// Simple ping route for quick testing
expressApp.get('/api/ping', (req, res) => {
  res.json({ ok: true, ts: Date.now() })
})

// Example API: send a message to a channel using Slack Web API
// Body: { channel: "C123..." | "#general", text: "Hello" }
expressApp.post('/api/notify', async (req, res) => {
  try {
    const channel = req.body.channel || process.env.SLACK_DEFAULT_CHANNEL
    const text = req.body.text || 'Hello from backend!'

    if (!channel) {
      return res.status(400).json({ ok: false, error: 'channel is required (or SLACK_DEFAULT_CHANNEL)' })
    }

    const result = await app.client.chat.postMessage({
      token: process.env.SLACK_BOT_TOKEN,
      channel,
      text,
    })

    res.json({ ok: true, channel, ts: result.ts })
  } catch (error) {
    console.error('notify error:', error)
    res.status(500).json({ ok: false, error: error.message })
  }
})

// Start the Bolt app (starts the Express server under the hood)
;(async () => {
  await app.start(port)
  console.log(`⚡️ Slack bot is running on port ${port}`)
  console.log('Health check: GET /health')
  console.log('Ping:        GET /api/ping')
  console.log('Notify:      POST /api/notify { channel, text }')
})()


