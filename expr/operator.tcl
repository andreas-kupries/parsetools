# -*- tcl -*-
# Copyright (c) 2012 Andreas Kupries <andreas_kupries@sourceforge.net>

# Database of operators for grammar expressions.
# New operators have to be added here.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5              ; # Required runtime.
package require quote                ; # Character quoting utilities.
package require lambda               ; # Readable apply.

# # ## ### ##### ######## ############# #####################
## API visibility

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

proc ::pt::operator::define {name arguments args} {
    variable op

    if {[dict exists $op $name]} {
	return -code error \
	    -errorcode {PT OPERATOR DEFINTION ALREADY} \
	    "Unable to define already known operator \"$name\""
    }

    if {[lindex $arguments end] eq "..."} {
	# For operators with an arbitrary number of arguments we need
	# at least one regular specification we can extend the spec
	# with during argument validation.

	if {[llength $arguments] < 2} {
	    return  -code error \
		-errorcode {PT OPERATOR ARGSPEC TOO_SHORT} \
		"Not enough arguments, expected fixed spec before ...-extension"
	}
	set inf 1
	set arguments [lrange $arguments 0 end-1]
	set max Inf
	set min [llength $arguments]
    } else {
	set inf 0
	set min [llength $arguments]
	set max $min
    }

    # Split arguments into type and names, for validation, and checks
    # of canonicity.

    set spec  {}
    set cargs op
    foreach s $arguments {
	if {[string match {*[*]} $s]} {
	    lappend spec *
	    lappend cargs [string range $s 1 end]
	} else {
	    lappend spec -
	    lappend cargs $s
	}
    }
    if {$inf} { lappend cargs args }

    dict set op $name [dict create min $min max $max spec $spec]

    # Default implementations for the various function vectors
    dict set op $name canonical [lambda $cargs { return 1   }] ; # unconditionally canonical
    dict set op $name print     [lambda $cargs { list <$op> }] ; # operator display.
    dict set op $name makecanon [lambda $cargs { lrange [info level 0] 1 end }]

    # Override the defaults with the user-specified scripts.
    dict for {f script} $args {
	dict set op $name $f [lambda $cargs $script]
    }

    # XXX TODO new operator - create ensemble to make various methods
    # XXX TODO accessible as subcommands of the operator, namely:
    # XXX TODO   new, leaf, print

    namespace eval $name {
	namespace export leaf print
	namespace ensemble create
    }

    # TODO: new/constructor
    proc ::pt::operator::${name}::leaf  {} \
	[list pt operator leaf $name]

    proc ::pt::operator::${name}::print {arguments} \
	"[lambda {args} {
        pt operator print $args
    } $name] {*}\$arguments"

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

    dict with op $operator {} ; # => min, max, spec, canonical

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

proc ::pt::operator::canonical {term msgvar} {
    set arguments [lassign $term operator]

    if {![dict exists $op $operator]} {
	upvar 1 $msgvar msg
	set msg "Invalid operator \"$operator\""
	return no
    }

    dict with op $operator {} ; # => min, max, spec, canonical

    if {![{*}$canonical $operator {*}$arguments]} {
	upvar 1 $msgvar msg
	set msg "Non canonical use"
	return no
    }

    if {$term ne [list {*}$term]} {
	upvar 1 $msgvar msg
	set msg "Irrelevant whitespace present"
	return no
    }

    return yes
}

proc ::pt::operator::print {term} {
    set arguments [lassign $term operator]

    if {![dict exists $op $operator]} {
	return -code error -errorcode {PT OPERATOR INVALID} \
	    "Invalid operator \"$operator\""
    }

    dict with op $operator {} ; # => print
    return [{*}$print $operator {*}$arguments]
}

proc ::pt::operator::makecanon {term} {
    set arguments [lassign $term operator]

    if {![dict exists $op $operator]} {
	return -code error -errorcode {PT OPERATOR INVALID} \
	    "Invalid operator \"$operator\""
    }

    dict with op $operator {} ; # => makecanon
    return [{*}$makecanon $operator {*}$arguments]
}

# # ## ### ##### ######## ############# #####################

namespace eval ::pt::operator {
    # Database of operators. Dictionary.
    # name -> list (min-arity max-arity spec)
    variable op {}
}

# # ## ### ##### ######## ############# #####################
## Public API - Standard operators

## Terminal symbols of various kinds (characters, symbolic tokens)
## These are all leaf nodes, with no, or only non-expression
## arguments.

pt operator define epsilon {} ; # nothing, empty sequence
pt operator define any     {} ; # any terminal symbol

# named terminal symbol
pt operator define token t print {
    list "@'[quote comment $t]'"
}

# token range
pt operator define range {a b} canonical {
    # range X X is not canonical
    expr {$a ne $b}
} makecanon {
    if {$a ne $b} { return [list $op $a $b] }
    list token $a
} print {
    list "range ([quote comment $a] .. [quote comment $b])"
}

# predefined (Tcl) character classes (string is X) as terminal symbol
pt operator define alpha    {}
pt operator define alnum    {}
pt operator define ascii    {}
pt operator define digit    {}
pt operator define graph    {}
pt operator define lower    {}
pt operator define print    {}
pt operator define punct    {}
pt operator define space    {}
pt operator define upper    {}
pt operator define wordchar {}
pt operator define xdigit   {}
pt operator define ddigit   {}

## Non-terminal symbols
## Still leaf nodes

# named non-terminal symbol
pt operator define symbol s print {
    list ($s)
}

## Actual operators I : Standard CFG
## These are all inner nodes with expression arguments.

# sequence of expressions
pt operator define sequence {e* ...} canonical {
    # single-expression sequence is not canonical
    expr {[llength $args]}
} makecanon {
    if {![llength $args]} { return $e }
    return [list $op $e {*}$args]
}

# unordered choice (CFG)
pt operator define uchoice {e* ...} canonical {
    # single-expression choice is not canonical
    expr {![llength $args]}
} makecanon {
    if {![llength $args]} { return $e }
    return [list $op $e {*}$args]
}

## Actual operators II : EBNF extensions, also PEG

pt operator define repeat0  e* ; # repeat zero or more
pt operator define repeat1  e* ; # repeat one or more
pt operator define optional e* ; # maybe, optional

## Actual operators III : PEG specific

pt operator define lookahead e* ; # look-ahead
pt operator define notahead  e* ; # negative look-ahead

# ordered choice of alternates
pt operator define ochoice {e* ...} canonical {
    # single-expression choice is not canonical
    expr {![llength $args]}
} makecanon {
    if {![llength $args]} { return $e }
    return [list $op $e {*}$args]
}

#pt operator define 
#pt operator define 

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::operator 1
return
