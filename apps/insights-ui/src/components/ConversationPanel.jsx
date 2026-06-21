import { useRef, useEffect, useState } from 'react'
import AgentMessageContent from './AgentMessageContent'

// Backend is non-streaming, so we can't get real phase events. These staged
// labels are time-based and reflect the known pipeline — the Fabric data-agent
// query dominates the wait (~25-30s), then the model composes the response.
const PENDING_STAGES = [
  { at: 0,  label: 'Querying Fabric data agent…' },
  { at: 12, label: 'Analyzing KPIs…' },
  { at: 24, label: 'Composing insights…' },
]

function PendingIndicator() {
  const [elapsed, setElapsed] = useState(0)

  useEffect(() => {
    const start = Date.now()
    const id = setInterval(() => {
      setElapsed(Math.floor((Date.now() - start) / 1000))
    }, 1000)
    return () => clearInterval(id)
  }, [])

  const label = PENDING_STAGES.reduce(
    (acc, s) => (elapsed >= s.at ? s.label : acc),
    PENDING_STAGES[0].label,
  )

  return (
    <span className="message-content message--pending">
      <span className="typing-indicator">
        <span /><span /><span />
      </span>
      <span className="typing-label">
        {label}{elapsed >= 3 ? ` · ${elapsed}s` : ''}
      </span>
    </span>
  )
}

function SendIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
      stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <line x1="22" y1="2" x2="11" y2="13" />
      <polygon points="22 2 15 22 11 13 2 9 22 2" />
    </svg>
  )
}

export default function ConversationPanel({ period, region, messages, isPending, onSend }) {
  const [input, setInput] = useState('')
  const bottomRef = useRef(null)

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, isPending])

  function handleSubmit(e) {
    e.preventDefault()
    const text = input.trim()
    if (!text || isPending) return
    setInput('')
    onSend(text)
  }

  function handleKeyDown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSubmit(e)
    }
  }

  return (
    <div className="conversation-panel">
      <div className="conversation-messages">
        {messages.length === 0 && !isPending && (
          <div className="conversation-empty">
            Ask a question about {region} &mdash; {period} performance.<br />
            <span style={{ fontSize: 11, opacity: .7 }}>
              e.g. "What drove the change in operating margin this period?"
            </span>
          </div>
        )}

        {messages.map((msg, i) => (
          <div key={i} className={`message message--${msg.role}`}>
            <span className="message-role">
              {msg.role === 'user' ? 'You' : 'AI Agent'}
            </span>
            {msg.role === 'user'
              ? <span className="message-content">{msg.content}</span>
              : <AgentMessageContent
                  content={msg.content}
                  key_drivers={msg.key_drivers}
                  analytics={msg.analytics}
                />
            }
          </div>
        ))}

        {isPending && (
          <div className="message message--assistant">
            <span className="message-role">AI Agent</span>
            <PendingIndicator />
          </div>
        )}

        <div ref={bottomRef} />
      </div>

      <form className="conversation-input" onSubmit={handleSubmit}>
        <textarea
          className="chat-textarea"
          rows={1}
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder={`Ask about KPIs, costs, drivers…`}
          disabled={isPending || !period || !region}
        />
        <button
          type="submit"
          className="btn-send"
          disabled={isPending || !input.trim() || !period || !region}
        >
          <SendIcon />
        </button>
      </form>
    </div>
  )
}
