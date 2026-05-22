import re
from collections import defaultdict

# ==========================================================
# ФАЙЛЫ
# ==========================================================

INPUT_FILE = r"C:\project\android\vpn\error.txt"
OUTPUT_FILE = r"C:\project\android\vpn\error_clean.txt"

# ==========================================================
# ОПЦИИ
# ==========================================================

IGNORE_TIMESTAMP = True
IGNORE_PID = True
IGNORE_HEX_ADDRESSES = True

IGNORE_LONG_NUMBERS = True
IGNORE_DYNAMIC_IDS = True

REMOVE_KNOWN_SPAM = True

COLLAPSE_IDENTICAL_MESSAGES = True

ADD_SUMMARY = True

# ==========================================================
# ШУМ ANDROID
# ==========================================================

DROP_CONTAINS = [
    "MotionDurationScaleImpl",
    "BroadcastFrameClock",
    "AndroidUiDispatcher",
]

DROP_TAGS = [
    "LocationManagerService"
]

# ==========================================================
# РЕГУЛЯРКИ
# ==========================================================

TIMESTAMP_RE = re.compile(
    r"^\d\d-\d\d\s+\d\d:\d\d:\d\d\.\d+\s+"
)

PID_RE = re.compile(
    r"\(\s*\d+\)"
)

HEX_RE = re.compile(
    r"@[0-9a-fA-F]+"
)

LONG_NUMBER_RE = re.compile(
    r"\d{8,}"
)

ID_RE = re.compile(
    r"\b\d{4,7}\b"
)

# ==========================================================
# СТАТИСТИКА
# ==========================================================

stats = defaultdict(int)

# ==========================================================
# НОРМАЛИЗАЦИЯ
# ==========================================================

def normalize(line: str) -> str:

    s = line

    if IGNORE_TIMESTAMP:
        s = TIMESTAMP_RE.sub("", s)

    if IGNORE_PID:
        s = PID_RE.sub("()", s)

    if IGNORE_HEX_ADDRESSES:
        s = HEX_RE.sub("@<HEX>", s)

    if IGNORE_LONG_NUMBERS:
        s = LONG_NUMBER_RE.sub("<LONG_NUM>", s)

    if IGNORE_DYNAMIC_IDS:
        s = ID_RE.sub("<ID>", s)

    return s.strip()

# ==========================================================
# СПАМ
# ==========================================================

def is_spam(line: str) -> bool:

    for tag in DROP_TAGS:
        if tag in line:
            return True

    for text in DROP_CONTAINS:
        if text in line:
            return True

    return False

# ==========================================================
# ОСНОВНОЙ ПРОХОД
# ==========================================================

message_counter = defaultdict(int)
message_example = {}

with open(
    INPUT_FILE,
    "r",
    encoding="utf-8",
    errors="ignore"
) as fin:

    for line in fin:

        if REMOVE_KNOWN_SPAM and is_spam(line):
            stats["Spam removed"] += 1
            continue

        norm = normalize(line)

        if not norm:
            continue

        message_counter[norm] += 1

        if norm not in message_example:
            message_example[norm] = norm

# ==========================================================
# СОХРАНЕНИЕ
# ==========================================================

with open(
    OUTPUT_FILE,
    "w",
    encoding="utf-8"
) as fout:

    messages = sorted(
        message_counter.items(),
        key=lambda x: x[1],
        reverse=True
    )

    for text, count in messages:

        if COLLAPSE_IDENTICAL_MESSAGES:

            if count > 1:
                fout.write(
                    f"{text} [x{count}]\n"
                )
            else:
                fout.write(
                    f"{text}\n"
                )

        else:

            for _ in range(count):
                fout.write(text + "\n")

    if ADD_SUMMARY:

        fout.write("\n")
        fout.write("=" * 70 + "\n")
        fout.write("SUMMARY\n")
        fout.write("=" * 70 + "\n")

        fout.write(
            f"Unique messages: {len(message_counter)}\n"
        )

        total = sum(message_counter.values())

        fout.write(
            f"Total messages: {total}\n"
        )

        for k, v in sorted(stats.items()):
            fout.write(
                f"{k}: {v}\n"
            )

print()
print("Готово")
print("Результат:")
print(OUTPUT_FILE)
