# -*- tcl -*-
# Copyright (c) 2012 Andreas Kupries <andreas_kupries@sourceforge.net>

# Database of operators for grammar expressions.
# New operators have to be added here.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5              ; # Required runtime.
package require

# # ## ### ##### ######## ############# #####################

namespace eval ::pt::operator {
    namespace export {[a-z]*}
    namespace ensemble create
}

namespace eval ::pt {
    namespace export operator
    namespace ensemble create
}

# # ## ### ##### ######## #############
## Public API - Operator database

proc ::pt::operator::def {name args} {
    variable op

    if {[dict exists $op $name]} {
	return -code error \
	    -errorcode {PT OPERATOR DEFINTION ALREADY} \
	    "Unable to define already known operator \"$name\""
    }

    if {[lindex $args end] eq "..."} {
	if {[llength $args] < 2} {
	    return  -code error \
		-errorcode {PT OPERATOR ARGSPEC TOO_SHORT} \
		"Not enough arguments, expected fixed spec before ...-extension"
	}
	set args [lrange $args 0 end-1]
	set max Inf
	set min [llength $args]
    } else {
	set min [llength $args]
	set max $min
    }

    foreach s $args {
	if {$s ni {- *}} {
	    return  -code error \
		-errorcode {PT OPERATOR ARGSPEC BAD} \
		"Bad argument spec \"$s\", expected one of -, or *"
	}
    }

    dict set op $name [dict create min $min max $max spec $args]

    # XXX TODO new operator - create ensemble to make various methods
    # XXX TODO accessible as subcommands of the operator, namely:
    # XXX TODO   new, leaf

    return
}

proc ::pt::operator::definition {name} {
    variable op

    if {![dict exists $op $name]} {
	return -code error \
	    -errorcode {PT OPERATOR DEFINTION UNKNOWN} \
	    "Unable to query unknown operator \"$name\""
    }

    return [dict get $op $name]
}

proc ::pt::operator::exists {name} {
    variable op
    return [dict exists $op $name]
}

proc ::pt::operator::leaf {name} {
    variable op

    if {![dict exists $op $name]} {
	return -code error \
	    -errorcode {PT OPERATOR DEFINTION UNKNOWN} \
	    "Unable to query unknown operator \"$name\""
    }

    return [expr {"*" ni [dict get $op $name spec]}]
}

proc ::pt::operator::valid {term msgvar} {
    variable op

    set arguments [lassign $term operator]

    if {![dict exists $op $operator]} {
	upvar 1 $msgvar msg
	set msg "Invalid operator \"$operator\""
	return no
    }

    set n [llength $arguments]

    dict with $op $operator {} ; # => min, max, spec

    if {($n < $min) || ($max < $n)} {
	upvar 1 $msgvar msg
	set msg "Wrong\#args for operator \"$operator\", expected "
	if {$min == $max} {
	    append msg "$min, got $n"
	} else {
	    append msg "($min ... $max), got $n"
	}
	return no
    }

    return yes
}

# # ## ### ##### ######## ############# #####################
## Public API - Standard operators

## Terminal symbols of various kinds (characters, symbolic tokens)

pt operator define epsilon    ; # leaf node, nothing, empty sequence of symbols
pt operator define any        ; # leaf node, any character as terminal
pt operator define token  -   ; # leaf node, named general terminal symbol
pt operator define char   -   ; # leaf node, character as terminal symbol
pt operator define range  - - ; # leaf node, char (or token) range as terminal symbol

pt operator define alpha      ; # leaf node, char-class (string is X)
pt operator define alnum      ; #            as terminal symbol
pt operator define ascii      ;
pt operator define digit      ;
pt operator define graph      ;
pt operator define lower      ;
pt operator define print      ;
pt operator define punct      ;
pt operator define space      ;
pt operator define upper      ;
pt operator define wordchar   ;
pt operator define xdigit     ;
pt operator define ddigit     ;

## Non-terminal symbols

pt operator define symbol -   ; # leaf node, named non-terminal symbol

## Actual operators I : Standard CFG

pt operator define sequence  * ... ; # inner node, sequence of input
pt operator define uchoice   * ... ; # inner node, unordered choice (CFG)

## Actual operators II : EBNF extensions, also PEG

pt operator define repeat0   *     ; # inner node, repeat zero or more
pt operator define repeat1   *     ; # inner node, repeat one or more
pt operator define optional  *     ; # inner node, maybe, optional

## Actual operators III : PEG specific

pt operator define lookahead *     ; # inner node, look-ahead
pt operator define notahead  *     ; # inner node, negative look-ahead
pt operator define ochoice   * ... ; # inner node, ordered choice of alternates

#pt operator define 
#pt operator define 

# # ## ### ##### ######## #############

namespace eval ::pt::operator {
    # Database of operators. Dictionary.
    # name -> list (min-arity max-arity spec)
    variable op {}

    ##
    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::pe 1
return
