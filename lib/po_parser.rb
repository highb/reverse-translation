require_relative 'parameterized_string'

# TODO: This module considers only happy cases (when the POT file is a valid
# POT file). Maybe add some error message output/error-handling? Not necessary
# for now, though.
module POParser
  # msgid and msgstr values are strings inside strings, so Ruby escape characters
  # get read with an extra backslash (e.g. "\n" becomes "\\n"). The regex below
  # recognizes these characters, while the ESCP_SUB gives the proper substitutions
  # for escape characters other than \\ or \", the latter of which can be replaced
  # as-is.
  ESCP_CH = /\\([\"\\abrnst])/
  ESCP_SUB = {
    "a" => "\a",
    "b" => "\b",
    "r" => "\r",
    "n" => "\n",
    "s" => "\s",
    "t" => "\t"
  }

  MSGID = /msgid(?:_plural)?/
  MSGSTR = /msgstr(?:\[\d+\])?/
  VALUE = /"(.*)"/

  MSGID_ENTRY = Regexp.new("(#{MSGID.to_s})"+"\s+"+"((?:#{VALUE.to_s}\n)+)")
  MSGSTR_ENTRY = Regexp.new("(#{MSGSTR.to_s})"+"\s+"+"((?:#{VALUE.to_s}\n)+)")
  MSGID_PART = Regexp.new("(?:#{MSGID_ENTRY.to_s})+")
  MSGSTR_PART = Regexp.new("(?:#{MSGSTR_ENTRY.to_s})+")

  # Hacky b/c scan returns everything in groups, but keeps it simple. If performance
  # is an issue (lots of arrays created), can hardcode the group vs. non-group regexes
  # if need be.
  PO_ENTRY = Regexp.new("(#{MSGID_PART.to_s+MSGSTR_PART.to_s})")

  # Bulk of the work is done here. 
  def self.parse_part(part, entry_re, param_re)
    part.scan(entry_re).inject({}) do |entries, entry|
     key = entry[0]
     val = entry[1].scan(VALUE).join.gsub(ESCP_CH) { |m| (sub = ESCP_SUB[m[1]]) ? sub : m[1] }.strip 
     return nil if val.empty?
     entries.merge(key => ParameterizedString.new(val, param_re))
    end
  end

  # Parses the given PO file, returning an array of entries. Each entry is an
  # array of pairs of maps. Each pair of maps are made up of two parts: 
  # <msg-id> and <msg-str>. <msg-id> will contain the values of the "msgid" and 
  # "msgid_plural" fields, while <msg-str> will contain values for "msgstr" and 
  # "msgstr[0]" fields. Note that a "value" here is a parametrized string object.
  # For example, here's what a single entry might look like:
  #
  # <msg-id> = { "msgid" => "Foo", "msgid_plural" => "Foos" }
  # <msg-str> = { "msgstr[0]" => "Translation 1", "msgstr[1]" => "Translation 2" }
  #
  # Note that the POParser will do the following:
  #    (1) All values will be stripped of leading and trailing whitespace.
  #
  #    (2) If any part of an entry, whether it is the msg-id or msg-str parts, have an
  #    empty value set after (1), then that entry will not be included.
  #
  def self.parse(path)
    contents = IO.read(path)

    # Guess the param regex. We choose the one w/ the most matches, tie-breakers are
    # in order of appearance in the PO_PARAMS array.
    _, ix = ParameterizedString::PARAM_RES.map { |re| contents.scan(re).length }.each_with_index.max
    param_re = ParameterizedString::PARAM_RES[ix]

    # Now parse the PO file's individual entries
    contents.scan(PO_ENTRY).map do |entry|
      entry = entry[0]
      msgid_entries = parse_part(MSGID_PART.match(entry)[0], MSGID_ENTRY, param_re)
      msgstr_entries = parse_part(MSGSTR_PART.match(entry)[0], MSGSTR_ENTRY, param_re)
      next nil unless msgid_entries && msgstr_entries
      [msgid_entries, msgstr_entries]
    end.compact
  end

  private_class_method :parse_part
end
