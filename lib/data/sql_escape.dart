/// Escape a string for use inside a single-quoted SQL literal.
String escapeSqlString(String value) => value.replaceAll("'", "''");
