-- Purpose: reusable, defensive parsing functions for the staging load.
--          Each one is a "safe cast": on anything it can't confidently
--          parse, it returns NULL (or the original value, for the mojibake
--          repair) instead of raising -- callers decide what NULL means
--          (soft-pass vs. hard-reject) per docs/cleaning_rules.md.
-- Inputs:  none.
-- Outputs: staging.parse_money, staging.safe_numeric, staging.repair_mojibake.
-- Grain:   n/a (scalar functions).

-- Parses "$1,234.56" and accounting-style "($1,234.56)" (negative) into
-- NUMERIC. See docs/cleaning_rules.md rule (b).
CREATE OR REPLACE FUNCTION staging.parse_money(raw_text TEXT)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    trimmed     TEXT;
    is_negative BOOLEAN;
    cleaned     TEXT;
BEGIN
    IF raw_text IS NULL THEN
        RETURN NULL;
    END IF;

    trimmed := btrim(raw_text);
    is_negative := trimmed ~ '^\(.*\)$';
    cleaned := regexp_replace(trimmed, '[()$,]', '', 'g');

    IF cleaned !~ '^-?\d+(\.\d+)?$' THEN
        RETURN NULL;
    END IF;

    RETURN CASE WHEN is_negative THEN -1 * cleaned::NUMERIC ELSE cleaned::NUMERIC END;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION staging.parse_money(TEXT) IS
    'Parses "$1,234.56" / "($1,234.56)" (negative) to NUMERIC; NULL if unparseable.';

-- Parses a plain numeric string (used for Quantity, which has no currency
-- formatting) into NUMERIC.
CREATE OR REPLACE FUNCTION staging.safe_numeric(raw_text TEXT)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    trimmed TEXT;
BEGIN
    IF raw_text IS NULL THEN
        RETURN NULL;
    END IF;

    trimmed := btrim(raw_text);
    IF trimmed !~ '^-?\d+(\.\d+)?$' THEN
        RETURN NULL;
    END IF;

    RETURN trimmed::NUMERIC;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION staging.safe_numeric(TEXT) IS
    'Parses a plain numeric string to NUMERIC; NULL if unparseable.';

-- Repairs UTF-8-read-as-Latin-1 mojibake (e.g. "Ã¢ÂÂ"). Some values in the
-- real dataset are double-encoded (the mistake happened twice upstream,
-- e.g. `17.25Ã¢Â\x80Â\x9d` for `17.25"`) -- one round-trip only peels off
-- one layer and leaves a still-mangled result, so this iterates the
-- LATIN1/UTF8 round-trip until the pattern no longer matches, the result
-- stops changing (fixed point), or a conversion fails, with a hard cap so
-- a pathological input can't loop forever. Falls back to the last good
-- value if a conversion errors -- important because the signature can
-- false-positive on legitimate accented text (e.g. "Château"), which must
-- survive unchanged (that round-trip fails on the very first iteration,
-- since a lone accented character isn't valid UTF-8 once mis-encoded, so
-- it exits immediately via the exception handler below).
-- See docs/cleaning_rules.md rule (f).
CREATE OR REPLACE FUNCTION staging.repair_mojibake(raw_text TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    current_text TEXT := raw_text;
    next_text    TEXT;
    iterations   INT := 0;
BEGIN
    IF raw_text IS NULL THEN
        RETURN NULL;
    END IF;

    WHILE current_text ~ '[ÃÂâ]' AND iterations < 5 LOOP
        BEGIN
            next_text := convert_from(convert_to(current_text, 'LATIN1'), 'UTF8');
        EXCEPTION WHEN OTHERS THEN
            EXIT;
        END;

        EXIT WHEN next_text = current_text;
        current_text := next_text;
        iterations := iterations + 1;
    END LOOP;

    RETURN current_text;
END;
$$;

COMMENT ON FUNCTION staging.repair_mojibake(TEXT) IS
    'Best-effort repair of UTF-8-as-Latin-1 mojibake; returns the original text on any failure.';

-- Trims and collapses runs of whitespace/newlines into a single space;
-- an all-whitespace value becomes NULL. Used for free-text fields per
-- docs/cleaning_rules.md rule (g).
CREATE OR REPLACE FUNCTION staging.collapse_whitespace(raw_text TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT NULLIF(regexp_replace(btrim(raw_text), '\s+', ' ', 'g'), '');
$$;

COMMENT ON FUNCTION staging.collapse_whitespace(TEXT) IS
    'Trims and collapses internal whitespace/newlines to a single space; all-whitespace becomes NULL.';
