"""
Shared helpers for notebook and script tests.
Used by notebooks to extract response text from Llama Stack Responses API objects.
"""


def response_text(r):
    """Extract full text from a Responses API response object (Llama Stack or OpenAI-compatible)."""
    t = getattr(r, "output_text", None)
    if t:
        return t
    if getattr(r, "output", None):
        for i in range(len(r.output) - 1, -1, -1):
            if getattr(r.output[i], "content", None):
                c = r.output[i].content[0]
                if getattr(c, "text", None):
                    return c.text
    return str(r.output) if getattr(r, "output", None) else ""
