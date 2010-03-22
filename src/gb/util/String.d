/**
 * String handling functions.
 *
 * A note on argument naming: ha and ne will be used as contractions of
 * "haystack" and "needle".
 *
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.util.String;

/**
 * Determines whether or not the given haystack starts with the needle.
 */

bool startsWith(char[] ha, char[] ne)
{
    return (ha.length >= ne.length && ha[0..ne.length] == ne);
}

/**
 * Determines whether or not the given haystack ends with the needle.
 */

bool endsWith(char[] ha, char[] ne)
{
    return (ha.length >= ne.length && ha[$-ne.length..$] == ne);
}

