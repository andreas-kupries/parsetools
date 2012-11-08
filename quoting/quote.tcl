# -*- tcl -*-
#
# Copyright (c) 2009-2012 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Various (un)quoting operations on characters.

# XXX TODO: Documentation. Tests.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5

namespace eval quote {
    namespace export unquote tcl string comment cstring
    namespace ensemble create
}

# ### ### ### ######### ######### #########
## API

proc ::quote::unquote {args} {
    if {1 == [llength $args]} { return [Unquote {*}$args] }
    set res {}
    foreach ch $args { lappend res [Unquote $ch] }
    return $res
}

proc ::quote::tcl {args} {
    if {1 == [llength $args]} { return [Tcl {*}$args] }
    set res {}
    foreach ch $args { lappend res [Tcl $ch] }
    return $res
}

proc ::quote::string {args} {
    if {1 == [llength $args]} { return [String {*}$args] }
    set res {}
    foreach ch $args { lappend res [String $ch] }
    return $res
}

proc ::quote::cstring {args} {
    if {1 == [llength $args]} { return [CString {*}$args] }
    set res {}
    foreach ch $args { lappend res [CString $ch] }
    return $res
}

proc ::quote::comment {args} {
    if {1 == [llength $args]} { return [Comment {*}$args] }
    set res {}
    foreach ch $args { lappend res [Comment $ch] }
    return $res
}

# ### ### ### ######### ######### #########
## Internal commands.

proc ::quote::Unquote {ch} {
    # A character, stored in (tcl) quoted form is transformed back
    # into a proper Tcl character (i.e. the internal representation).

    switch -exact -- $ch {
	"\\n"  {return \n}
	"\\t"  {return \t}
	"\\r"  {return \r}
	"\\["  {return \[}
	"\\]"  {return \]}
	"\\'"  {return '}
	"\\\"" {return "\""}
	"\\\\" {return \\}
    }

    if {[regexp {^\\([0-2][0-7][0-7])$} $ch -> ocode]} {
	return [format %c $ocode]

    } elseif {[regexp {^\\([0-7][0-7]?)$} $ch -> ocode]} {
	return [format %c 0$ocode]

    } elseif {[regexp {^\\u([[:xdigit:]][[:xdigit:]]?[[:xdigit:]]?[[:xdigit:]]?)$} $ch -> hcode]} {
	return [format %c 0x$hcode]

    }

    return $ch
}

proc ::quote::Tcl {ch} {
    # Converts a Tcl character (internal representation) into a string
    # which is accepted by the Tcl parser, will regenerate the
    # character in question and is portable (7bit ASCII).

    # Special characters

    switch -exact -- $ch {
	"\n" {return "\\n"}
	"\r" {return "\\r"}
	"\t" {return "\\t"}
	"\\" - "\;" -
	" "  - "\"" -
	"("  - ")"  -
	"\{" - "\}" -
	"\[" - "\]" {
	    # Quote space and all the brackets as well, using octal,
	    # for easy impure list-ness.

	    scan $ch %c chcode
	    return \\[format %o $chcode]
	}
    }

    scan $ch %c chcode

    # Control characters: Octal
    if {[::string is control -strict $ch]} {
	return \\[format %o $chcode]
    }

    # Beyond 7-bit ASCII: Unicode
    if {$chcode > 127} {
	return \\u[format %04x $chcode]
    }

    # Regular character: Is its own representation.
    return $ch
}

proc ::quote::String {ch} {
    # Converts a Tcl character (internal representation) into a string
    # which is accepted by the Tcl parser and will generate a human
    # readable representation of the character in question, one which
    # when written to a channel (via puts) describes the character
    # without using any unprintable (non-portable) characters. It may
    # use backslash-quoting. High utf characters are quoted to avoid
    # problems with the still prevalent ascii terminals. It is assumed
    # that the string will be used in a ""-quoted environment.

    # Special characters

    switch -exact -- $ch {
	" "  {return "<blank>"}
	"\n" {return "\\\\n"}
	"\r" {return "\\\\r"}
	"\t" {return "\\\\t"}
	"\"" - "\\" - "\;" -
	"("  - ")"  -
	"\{" - "\}" -
	"\[" - "\]" {
	    return \\$ch
	}
    }

    scan $ch %c chcode

    # Control characters: Octal
    if {[::string is control -strict $ch]} {
	return \\\\[format %o $chcode]
    }

    # Beyond 7-bit ASCII: Unicode
    if {$chcode > 127} {
	return \\\\u[format %04x $chcode]
    }

    # Regular character: Is its own representation.
    return $ch
}

proc ::quote::CString {ch} {
    # Converts a Tcl character (internal representation) into a string
    # which is accepted by a C compiler and will generate a human
    # readable representation of the character in question, one which
    # when written to a channel (via puts) describes the character
    # without using any unprintable (non-portable) characters. It may
    # use backslash-quoting. High utf characters are quoted to avoid
    # problems with the still prevalent ascii terminals. It is assumed
    # that the string will be used in a ""-quoted environment.

    # Special characters

    switch -exact -- $ch {
	"\n" {return "\\\\n"}
	"\r" {return "\\\\r"}
	"\t" {return "\\\\t"}
	"\"" - "\\" {
	    return \\$ch
	}
    }

    scan $ch %c chcode

    # Control characters: Octal
    if {[::string is control -strict $ch]} {
	return \\\\[format %o $chcode]
    }

    # Beyond 7-bit ASCII: Unicode
    if {$chcode > 127} {
	return \\\\u[format %04x $chcode]
    }

    # Regular character: Is its own representation.
    return $ch
}

proc ::quote::Comment {ch} {
    # Converts a Tcl character (internal representation) into a string
    # which is accepted by the Tcl parser when used within a Tcl
    # comment.

    # Special characters

    switch -exact -- $ch {
	" "  {return "<blank>"}
	"\n" {return "\\n"}
	"\r" {return "\\r"}
	"\t" {return "\\t"}
	"\"" -
	"\{" - "\}" -
	"("  - ")"  {
	    return \\$ch
	}
    }

    scan $ch %c chcode

    # Control characters: Octal
    if {[::string is control -strict $ch]} {
	return \\[format %o $chcode]
    }

    # Beyond 7-bit ASCII: Unicode
    if {$chcode > 127} {
	return \\u[format %04x $chcode]
    }

    # Regular character: Is its own representation.
    return $ch
}

# ### ### ### ######### ######### #########
## Ready

package provide quote 1

