import { useRef, useEffect, useState } from 'react'

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
            <span className="message-content">{msg.content}</span>
          </div>
        ))}

        {isPending && (
          <div className="message message--assistant">
            <span className="message-role">AI Agent</span>
            <span className="message-content message--pending">
              <span className="typing-indicator">
                <span /><span /><span />
              </span>
            </span>
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
