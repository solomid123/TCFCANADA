"""The 39-item training blueprint is an app design, not an official item distribution."""
import re
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


def blueprint(number: int) -> tuple[str, str]:
    kind = "picture" if number <= 4 else "response" if number <= 10 else "dialogue" if number <= 23 else "report"
    level = "A1" if number <= 4 else "A2" if number <= 10 else "B1" if number <= 19 else "B2" if number <= 29 else "C1" if number <= 36 else "C2"
    return kind, level


class Turn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    speaker: Literal["female", "male"]
    text: str = Field(min_length=1, max_length=2200)


class Question(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: int = Field(ge=1, le=39)
    kind: Literal["picture", "response", "dialogue", "report"]
    level: Literal["A1", "A2", "B1", "B2", "C1", "C2"]
    question: str = Field(min_length=5, max_length=350)
    turns: list[Turn] = Field(min_length=1, max_length=8)
    options: list[str] = Field(min_length=4, max_length=4)
    correct_index: int = Field(ge=0, le=3)
    explanation: str = Field(min_length=20, max_length=1200)
    image_prompt: str | None = Field(default=None, max_length=1800)

    @model_validator(mode="after")
    def validate_item(self):
        if (self.kind, self.level) != blueprint(self.id):
            raise ValueError("Item does not follow the requested training blueprint")
        normalized = [re.sub(r"\s+", " ", option.strip().casefold()) for option in self.options]
        if any(not option or len(option) > 350 for option in normalized) or len(set(normalized)) != 4:
            raise ValueError("Four distinct, nonempty choices are required")
        if (self.kind == "picture") != bool(self.image_prompt):
            raise ValueError("Only picture questions must include an image prompt")
        words = sum(len(turn.text.split()) for turn in self.turns)
        if words > 260:
            raise ValueError("Audio script exceeds the per-question word budget")
        if self.kind == "dialogue" and len({turn.speaker for turn in self.turns}) < 2:
            raise ValueError("A dialogue requires two speakers")
        return self


class Batch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    questions: list[Question]


class Submission(BaseModel):
    answers: dict[int, int] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_answers(self):
        if any(number not in range(1, 40) or answer not in range(4) for number, answer in self.answers.items()):
            raise ValueError("Invalid question number or answer")
        return self
