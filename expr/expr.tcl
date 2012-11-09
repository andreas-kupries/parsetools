# -*- tcl -*-
# Copyright (c) 2009-2012 Andreas Kupries <andreas_kupries@sourceforge.net>

# Grammar expression handling.
# - (De)serialize expressions, various formats
# - Validate expressions.
# - Walk (visit) expressions.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5              ; # Required runtime.
package require quote                ; # Character quoting utilities.
package require lambda               ; # Readable apply.
package require try                  ; # try/finally for 8.5
package require pt::operator         ; # Operators in expressions.

# # ## ### ##### ######## ############# #####################
## API visibility

namespace eval ::pt::expr {
    namespace export {[a-z]*}
    namespace ensemble create

    namespace import ::pt::operator
}

namespace eval ::pt {
    namespace export expr
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################
## Public API I - Visit expressions.
##
## - Bottom up.             Generation of synthetic attributes.
## - Top-down (left-right). Management of an inherited context.
## - Down/up. Combination managing an inherit context and synthetic attributes.

namespace eval ::pt::expr::walk {
    namespace export up down
    namespace ensemble create
}

proc ::pt::expr::walk::up {cmdprefix expression} {
    if {![operator valid $expression msg]} {
	return -code error -errorcode {PT EXPR INVALID} $msg
    }

    set arguments [lassign $expression operator]

    set spec [dict get [operator definition $operator] spec]

    # Extend spec to match the arguments. This can only happen for
    # max-arity == +Inf, any other mismatch is rejected by the
    # validation above.
    set k [llength $spec]
    set n [llength $arguments]
    if {$k < $n} {
	lappend spec {*}[lrepeat [- $n $k] [lindex $spec end]]
    }

    # Process the arguments first (bottom-up!)
    foreach s $spec a $arguments {
	if {$s eq "-"} {
	    lappend eargs $a
	} else {
	    # Recurse into expandable arguments.
	    lappend eargs [up $cmdprefix $a]
	}
    }

    # Now process the current node, providing both original and
    # processed arguments to the callback.

    # Note: The operator name is used as sub-method in the call. The
    # result of the call goes into the caller as part of the processed
    # information.

    return [{*}$cmdprefix $operator $arguments $eargs]
}

proc ::pt::expr::walk::down {contextvar cmdprefix expression} {
    upvar 1 $contextvar context

    if {![operator valid $expression msg]} {
	return -code error -errorcode {PT EXPR INVALID} $msg
    }

    set arguments [lassign $expression operator]

    # Process the current node first, providing context and original
    # arguments to the callback. Note: The operator name is used as
    # sub-method in the call. The result of the call is ignored.

    {*}$cmdprefix $operator context $arguments

    # The context however may have changed and is provided to the
    # child nodes, whose processing is now done.

    set spec [dict get [operator definition $operator] spec]

    # Extend spec to match the arguments. This can only happen for
    # max-arity == +Inf, any other mismatch is rejected by the
    # validation above.
    set k [llength $spec]
    set n [llength $arguments]
    if {$k < $n} {
	lappend spec {*}[lrepeat [- $n $k] [lindex $spec end]]
    }

    # Process the arguments last
    foreach s $spec a $arguments {
	if {$s eq "*"} {
	    # Recurse into expandable arguments.
	    down context $cmdprefix $a
	}
    }
    return
}

proc ::pt::expr::walk::downup {contextvar cmdprefix expression} {
    upvar 1 $contextvar context

    if {![operator valid $expression msg]} {
	return -code error -errorcode {PT EXPR INVALID} $msg
    }

    set arguments [lassign $expression operator]

    # Process the current node first, providing context and original
    # arguments to the callback. Note: The operator name is used as
    # sub-method in the call. The result of the call is ignored.

    {*}$cmdprefix $operator down context $arguments

    # The context however may have changed and is provided to the
    # child nodes, whose processing is now done.

    set spec [dict get [operator definition $operator] spec]

    # Extend spec to match the arguments. This can only happen for
    # max-arity == +Inf, any other mismatch is rejected by the
    # validation above.
    set k [llength $spec]
    set n [llength $arguments]
    if {$k < $n} {
	lappend spec {*}[lrepeat [- $n $k] [lindex $spec end]]
    }

    # Process the arguments...
    foreach s $spec a $arguments {
	if {$s eq "-"} {
	    lappend eargs $a
	} else {
	    # Recurse into expandable arguments.
	    lappend eargs [downup context $cmdprefix $a]
	}
    }

    # And process the current node a second time as we come back from
    # the children.

    return [{*}$cmdprefix $operator up context $arguments $eargs]
}

# # ## ### ##### ######## #############
## Public API II - 

proc ::pt::expr::valid {expression msgvar} {
    # Validate the entire expression. The specified callback does
    # nothing, because the checks are done by the walker itself.

    try {
	walk up [lambda {op oargs eargs} {}] $expression
    } trap {PT EXPR INVALID} {e o} {
	upvar 1 $msgvar msg
	set msg $e
	return no
    }
    return yes
}

proc ::pt::expr::canonical {expression msgvar} {
    try {
	walk up [lambda {op oargs eargs} {
	    # TODO: Look for (range X X) terms.
	    # Or, alternativively, define a 'canonical' method for
	    # operators, and use it here, keeping things generic.

	    # Check against irelevant whitespace, abort quickly.
	    set canonical [string equal $expression [list {*}$expression]]
	    if {!$canonical} {
		return -code error \
		    -errorcode {PT KETTLE INVALID} \
		    "Irrelevant whitespace"
	    }
	    return
	}]
    } trap {PT EXPR INVALID} {e o} {
	upvar 1 $msgvar msg
	set msg $e
	return no
    }
    return yes
}


return

# # ## ### ##### ######## #############

proc ::pt::expr::canonicalize {serial} {
    verify $serial iscanonical
    if {$iscanonical} { return $serial }
    return [bottomup [list [namespace current]::Canonicalize] $serial]
}

proc ::pt::expr::Canonicalize {pe op arguments} {
    # The input is mostly already pulled apart into its elements. Now
    # we construct a pure list out of them, and if necessary, convert
    # a {.. x x} expression into the canonical {t x} representation.

    if {($op eq ".." ) &&
	([lindex $arguments 0] eq [lindex $arguments 1])} {
	return [list t [lindex $arguments 0]]
    }
    return [list $op {*}$arguments]
}

# # ## ### ##### ######## #############

# Converts a parsing expression serialization into a human readable
# string for test results. It assumes that the serialization is at
# least structurally sound.

proc ::pt::expr::print {serial} {
    return [join [bottomup [list [namespace current]::Print] $serial] \n]
}

proc ::pt::expr::Print {pe op arguments} {
    switch -exact -- $op {
	epsilon - alpha - alnum - ascii - digit - graph - lower - print - \
	    punct - space - upper - wordchar - xdigit - ddigit - dot {
		return [list <$op>]
	    }
	str { return [list "\"[join [char quote comment {*}$arguments] {}]\""] }
	cl  { return [list "\[[join [char quote comment {*}$arguments] {}]\]"] }
	n   { return [list "([lindex $arguments 0])"] }
	t   { return [list "'[char quote comment [lindex $arguments 0]]'"] }
	..  {
	    lassign $arguments ca ce
	    return [list "range ([char quote comment $ca] .. [char quote comment $ce])"]
	}
    }
    # The arguments are already processed for printing

    set out {}
    lappend out $op
    foreach a $arguments {
	foreach line $a {
	    lappend out "    $line"
	}
    }
    return $out
}

# # ## ### ##### ######## #############

proc ::pt::expr::equal {seriala serialb} {
    return [string equal \
		[canonicalize $seriala] \
		[canonicalize $serialb]]
}

# # ## ### ##### ######## #############

# # ## ### ##### ######## #############

namespace eval ::pt::expr {
    # # ## ### ##### ######## #############
    ## Strings for error messages.

    variable ourprefix    "error in serialization:"
    variable ourempty     " got empty string"
    variable ourimpure    " has irrelevant whitespace or (.. X X)"

    # # ## ### ##### ######## #############
    ## operator arities

    ##
    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::expr 1
return
