"""줄 번호를 보존하는 YAML 읽기."""

from pathlib import Path

import yaml
from yaml.constructor import SafeConstructor
from yaml.nodes import MappingNode, SequenceNode


def load_with_lines(path: Path) -> list[tuple[dict[str, object], int]]:
    """최상위 리스트의 각 항목과 1부터 세는 줄 번호를 돌려줍니다."""
    root = yaml.compose(path.read_text(encoding="utf-8"), Loader=yaml.SafeLoader)
    if root is None:
        return []
    if not isinstance(root, SequenceNode):
        raise yaml.YAMLError("최상위는 리스트여야 합니다")
    constructor = SafeConstructor()
    items: list[tuple[dict[str, object], int]] = []
    for node in root.value:
        line = node.start_mark.line + 1
        if not isinstance(node, MappingNode):
            raise yaml.YAMLError(f"{line}줄: 항목은 매핑이어야 합니다")
        mapping = constructor.construct_object(node, deep=True)
        items.append((mapping, line))
    return items
