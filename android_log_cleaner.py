import re
import hashlib
from collections import defaultdict

# ==========================================================
# НАСТРОЙКИ
# ==========================================================

INPUT_FILE = r"C:\project\android\vpn\error.txt"
OUTPUT_FILE = r"C:\project\android\vpn\error_clean.txt"

ENABLE_COLLAPSE_CONSECUTIVE_LINES = True
ENABLE_COLLAPSE_IDENTICAL_LOG_MESSAGES = True
ENABLE_COLLAPSE_IDENTICAL_EXCEPTIONS = True

IGNORE_TIMESTAMP = True
IGNORE_PID = True
IGNORE_TID = True
IGNORE_HEX_ADDRESSES = True
IGNORE_NUMBERS = False

REMOVE_KNOWN_SPAM = True
REMOVE_DUPLICATE_STACK_FRAMES = True

KEEP_ONLY_FIRST_APP_FRAME = True
KEEP_ONLY_APP_FRAMES = False

ADD_SUMMARY = True

APP_PACKAGE = "com.alisavpn"

# ==========================================================
# СПАМ
# ==========================================================

SPAM_PATTERNS = [
    "MotionDurationScaleImpl",
    "BroadcastFrameClock",
    "AndroidUiDispatcher",
    "blocking 0,0 location from gps provider",
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

TID_RE = re.compile(
    r"\s+\d+\s+\d+\s+[A-Z]\s"
)

HEX_RE = re.compile(
    r"@[0-9a-fA-F]+"
)

NUMBER_RE = re.compile(
    r"\d+"
)

EXCEPTION_RE = re.compile(
    r"([A-Za-z0-9_$.]*(Exception|Error))"
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

    if IGNORE_TID:
        s = TID_RE.sub(" ", s)

    if IGNORE_HEX_ADDRESSES:
        s = HEX_RE.sub("@<HEX>", s)

    if IGNORE_NUMBERS:
        s = NUMBER_RE.sub("<NUM>", s)

    return s.strip()


# ==========================================================
# СПАМ
# ==========================================================

def is_spam(line: str) -> bool:
    for p in SPAM_PATTERNS:
        if p in line:
            return True
    return False


# ==========================================================
# ОПРЕДЕЛЕНИЕ КАДРА СТЕКА
# ==========================================================

def is_stack_frame(line: str) -> bool:
    text = line.strip()
    return text.startswith("at ") or " at " in text


# ==========================================================
# ЧТЕНИЕ
# ==========================================================

with open(
    INPUT_FILE,
    "r",
    encoding="utf-8",
    errors="ignore"
) as f:
    lines = f.readlines()

# ==========================================================
# УДАЛЕНИЕ СПАМА
# ==========================================================

filtered = []

for line in lines:

    if REMOVE_KNOWN_SPAM and is_spam(line):
        stats["Spam lines removed"] += 1
        continue

    filtered.append(line)

# ==========================================================
# УДАЛЕНИЕ ДУБЛЕЙ КАДРОВ СТЕКА
# ==========================================================

if REMOVE_DUPLICATE_STACK_FRAMES:

    result = []
    seen_frames = set()

    for line in filtered:

        if is_stack_frame(line):

            key = normalize(line)

            if key in seen_frames:
                stats["Duplicate stack frames removed"] += 1
                continue

            seen_frames.add(key)

        else:
            seen_frames.clear()

        result.append(line)

    filtered = result

# ==========================================================
# ОСТАВЛЯТЬ ТОЛЬКО ПЕРВЫЙ КАДР ПРИЛОЖЕНИЯ
# ==========================================================

if KEEP_ONLY_FIRST_APP_FRAME:

    result = []
    inside_stack = False
    found_app_frame = False

    for line in filtered:

        if "Exception" in line or "Error" in line:
            inside_stack = True
            found_app_frame = False
            result.append(line)
            continue

        if inside_stack and is_stack_frame(line):

            if APP_PACKAGE in line:

                if not found_app_frame:
                    result.append(line)
                    found_app_frame = True

                continue

            else:
                continue

        if inside_stack and line.strip() == "":
            inside_stack = False

        result.append(line)

    filtered = result

# ==========================================================
# ОСТАВЛЯТЬ ТОЛЬКО КАДРЫ ПРИЛОЖЕНИЯ
# ==========================================================

if KEEP_ONLY_APP_FRAMES:

    result = []

    for line in filtered:

        if is_stack_frame(line):

            if APP_PACKAGE not in line:
                continue

        result.append(line)

    filtered = result

# ==========================================================
# СВОРАЧИВАНИЕ ПОВТОРЯЮЩИХСЯ ПОДРЯД СООБЩЕНИЙ
# ==========================================================

if ENABLE_COLLAPSE_CONSECUTIVE_LINES:

    result = []

    prev = None
    count = 0

    for line in filtered:

        norm = normalize(line)

        if norm == prev:
            count += 1
            stats["Duplicate lines removed"] += 1
            continue

        if count:
            result.append(
                f"[REPEATED {count} TIMES]\n"
            )

        result.append(line)

        count = 0
        prev = norm

    if count:
        result.append(
            f"[REPEATED {count} TIMES]\n"
        )

    filtered = result

# ==========================================================
# СВОРАЧИВАНИЕ ОДИНАКОВЫХ СООБЩЕНИЙ
# ==========================================================

if ENABLE_COLLAPSE_IDENTICAL_LOG_MESSAGES:

    counter = defaultdict(int)
    originals = {}

    for line in filtered:

        norm = normalize(line)

        counter[norm] += 1

        if norm not in originals:
            originals[norm] = line

    result = []

    for norm, count in counter.items():

        line = originals[norm].rstrip()

        if count > 1:
            result.append(
                f"{line} [x{count}]\n"
            )
        else:
            result.append(
                line + "\n"
            )

    filtered = result

# ==========================================================
# ГРУППИРОВКА ИСКЛЮЧЕНИЙ
# ==========================================================

exception_groups = defaultdict(list)

if ENABLE_COLLAPSE_IDENTICAL_EXCEPTIONS:

    for line in filtered:

        m = EXCEPTION_RE.search(line)

        if m:
            exception_name = m.group(1)
            exception_groups[exception_name].append(line)

# ==========================================================
# ЗАПИСЬ
# ==========================================================

with open(
    OUTPUT_FILE,
    "w",
    encoding="utf-8"
) as f:

    for line in filtered:
        f.write(line)

    if ADD_SUMMARY:

        f.write("\n")
        f.write("=" * 70 + "\n")
        f.write("SUMMARY\n")
        f.write("=" * 70 + "\n")

        for key, value in sorted(stats.items()):
            f.write(f"{key}: {value}\n")

        if exception_groups:

            f.write("\n")
            f.write("Exceptions:\n")

            for name, items in sorted(
                exception_groups.items(),
                key=lambda x: len(x[1]),
                reverse=True
            ):
                f.write(
                    f"{name}: {len(items)}\n"
                )

print()
print("Готово")
print("Результат:")
print(OUTPUT_FILE)
