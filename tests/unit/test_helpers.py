import sys
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from helpers import response_text  # noqa: E402


class TestResponseText:
    def test_output_text_attribute(self):
        r = SimpleNamespace(output_text="Hello world", output=None)
        assert response_text(r) == "Hello world"

    def test_openai_style_output(self):
        content = SimpleNamespace(text="Paris is the capital", type="output_text")
        message = SimpleNamespace(type="message", content=[content], role="assistant")
        r = SimpleNamespace(output_text=None, output=[message])
        assert "Paris" in response_text(r)

    def test_empty_output(self):
        r = SimpleNamespace(output_text=None, output=[])
        assert response_text(r) == ""

    def test_none_output(self):
        r = SimpleNamespace(output_text=None, output=None)
        assert response_text(r) == ""

    def test_output_text_takes_priority(self):
        content = SimpleNamespace(text="from output", type="output_text")
        message = SimpleNamespace(type="message", content=[content])
        r = SimpleNamespace(output_text="from output_text", output=[message])
        assert response_text(r) == "from output_text"

    def test_content_without_text(self):
        content = SimpleNamespace(type="image", text=None)
        message = SimpleNamespace(type="message", content=[content])
        r = SimpleNamespace(output_text=None, output=[message])
        result = response_text(r)
        assert isinstance(result, str)

    def test_multiple_output_items(self):
        c1 = SimpleNamespace(text="Hello ", type="output_text")
        c2 = SimpleNamespace(text="world", type="output_text")
        m1 = SimpleNamespace(type="message", content=[c1])
        m2 = SimpleNamespace(type="message", content=[c2])
        r = SimpleNamespace(output_text=None, output=[m1, m2])
        text = response_text(r)
        assert "world" in text
