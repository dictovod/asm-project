import re
from collections import defaultdict

# ==========================================================
# НАСТРОЙКИ
# ==========================================================

INPUT_FILE = r"C:\project\android\vpn\error.txt"
OUTPUT_FILE = r"C:\project\android\vpn\error_clean.txt"

APP_PACKAGE = "com.alisavpn"

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

ENABLE_EXCEPTION_GROUPING = True

KEEP_ONLY_ERROR_LEVELS = False

ADD_SUMMARY = True

# ==========================================================
# ФИЛЬТРЫ
# ==========================================================

REMOVE_TAGS = [
    "LocationManagerService",
]

REMOVE_CONTAINS = [
    "MotionDurationScaleImpl",
    "BroadcastFrameClock",
    "AndroidUiDispatcher",
]

ERROR_LEVELS = [
    " E/",
    " F/",
    "WTF",
]

# ==========================================================
# РЕГУЛЯРКИ
# ==========================================================

TIMESTAMP_RE = re.compile(
    r"^\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+\s+"
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

EXCEPTION_NAME_RE = re.compile(
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

    for tag in REMOVE_TAGS:
        if tag in line:
            return True

    for text in REMOVE_CONTAINS:
        if text in line:
            return True

    return False


# ==========================================================
# ОШИБКИ
# ==========================================================

def is_error_line(line: str) -> bool:

    if not KEEP_ONLY_ERROR_LEVELS:
        return True

    for level in ERROR_LEVELS:
        if level in line:
            return True

    return False


# ==========================================================
# ПОИСК STACKTRACE
# ==========================================================

def collect_exception_blocks(lines):

    blocks = []

    current = []

    inside = False

    for line in lines:

        if (
            "FATAL EXCEPTION" in line
            or "Exception" in line
            or "Error" in line
        ):

            if current:
                blocks.append(current)

            current = [line]
            inside = True
            continue

        if inside:

            if line.strip() == "":
                blocks.append(current)
                current = []
                inside = False
            else:
                current.append(line)

    if current:
        blocks.append(current)

    return blocks


# ==========================================================
# ПЕРВЫЙ КАДР ПРИЛОЖЕНИЯ
# ==========================================================

def extract_main_frame(block):

    for line in block:

        if APP_PACKAGE in line:
            return line.strip()

    for line in block:

        if " at " in line:
            return line.strip()

    return "unknown"


# ==========================================================
# ГРУППИРОВКА ИСКЛЮЧЕНИЙ
# ==========================================================

def build_exception_report(lines):

    exceptions = defaultdict(
        lambda: {
            "count": 0,
            "frame": ""
        }
    )

    blocks = collect_exception_blocks(lines)

    for block in blocks:

        exception_name = None

        for line in block:

            m = EXCEPTION_NAME_RE.search(line)

            if m:
                exception_name = m.group(1)
                break

        if not exception_name:
            continue

        exceptions[exception_name]["count"] += 1

        if not exceptions[exception_name]["frame"]:
            exceptions[exception_name]["frame"] = (
                extract_main_frame(block)
            )

    return exceptions


# ==========================================================
# ЧТЕНИЕ И ОБРАБОТКА
# ==========================================================

message_counter = defaultdict(int)

original_lines = []

with open(
    INPUT_FILE,
    "r",
    encoding="utf-8",
    errors="ignore"
) as fin:

    for line in fin:

        original_lines.append(line)

        if REMOVE_KNOWN_SPAM and is_spam(line):
            stats["Spam removed"] += 1
            continue

        if not is_error_line(line):
            stats["Non-error lines removed"] += 1
            continue

        normalized = normalize(line)

        if not normalized:
            continue

        message_counter[normalized] += 1

# ==========================================================
# ОТЧЁТ ПО ИСКЛЮЧЕНИЯМ
# ==========================================================

exception_report = {}

if ENABLE_EXCEPTION_GROUPING:
    exception_report = build_exception_report(
        original_lines
    )

# ==========================================================
# ЗАПИСЬ
# ==========================================================

with open(
    OUTPUT_FILE,
    "w",
    encoding="utf-8"
) as fout:

    # ------------------------------------------------------
    # CRASH REPORT
    # ------------------------------------------------------

    if exception_report:

        fout.write("=" * 70 + "\n")
        fout.write("CRASH REPORT\n")
        fout.write("=" * 70 + "\n\n")

        for exc_name, data in sorted(
            exception_report.items(),
            key=lambda x: x[1]["count"],
            reverse=True
        ):

            fout.write(exc_name + "\n")
            fout.write(
                f"Occurrences: {data['count']}\n\n"
            )

            fout.write(
                f"Main frame:\n{data['frame']}\n\n"
            )

            fout.write(
                "-" * 70 + "\n\n"
            )

    # ------------------------------------------------------
    # NORMALIZED LOG
    # ------------------------------------------------------

    fout.write("=" * 70 + "\n")
    fout.write("NORMALIZED LOG\n")
    fout.write("=" * 70 + "\n\n")

    sorted_messages = sorted(
        message_counter.items(),
        key=lambda x: x[1],
        reverse=True
    )

    duplicate_removed = 0

    for text, count in sorted_messages:

        if COLLAPSE_IDENTICAL_MESSAGES:

            if count > 1:

                fout.write(
                    f"{text} [x{count}]\n"
                )

                duplicate_removed += (
                    count - 1
                )

            else:

                fout.write(
                    text + "\n"
                )

        else:

            for _ in range(count):
                fout.write(text + "\n")

    stats["Duplicate messages removed"] = (
        duplicate_removed
    )

    # ------------------------------------------------------
    # SUMMARY
    # ------------------------------------------------------

    if ADD_SUMMARY:

        fout.write("\n")
        fout.write("=" * 70 + "\n")
        fout.write("SUMMARY\n")
        fout.write("=" * 70 + "\n")

        fout.write(
            f"Unique messages: "
            f"{len(message_counter)}\n"
        )

        fout.write(
            f"Unique exceptions: "
            f"{len(exception_report)}\n"
        )

        fout.write(
            f"Total processed lines: "
            f"{len(original_lines)}\n"
        )

        for key, value in sorted(
            stats.items()
        ):
            fout.write(
                f"{key}: {value}\n"
            )

print()
print("Готово")
print("Результат:")
print(OUTPUT_FILE)
