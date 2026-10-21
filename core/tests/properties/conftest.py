# property 테스트의 예제 수 (D81). PR·로컬은 quick, 정기 실행(core.yml schedule)은 full로 돈다.
# derandomize로 같은 profile이면 언제나 같은 입력을 만든다.
import os

from hypothesis import settings

settings.register_profile("quick", max_examples=50, deadline=None, derandomize=True)
settings.register_profile("full", max_examples=300, deadline=None, derandomize=True)
settings.load_profile(os.environ.get("HYPOTHESIS_PROFILE", "quick"))
