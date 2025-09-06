eval_with_output() {
    local input_string="$1"
    local stdout_file stderr_file exit_code

    # Create temporary files for stdout and stderr
    stdout_file=$(mktemp)
    stderr_file=$(mktemp)

    # Print the code being executed
    echo "Code:"
    echo "$input_string"
    echo

    # Evaluate the string in a subshell, capturing stdout and stderr
    # Redirect all output of the command to the temporary files
    (
        # Redirect stdout and stderr for the entire subshell
        exec >"$stdout_file" 2>"$stderr_file"
        eval "$input_string"
    )
    exit_code=$?

    # Print stdout
    echo "Stdout:"
    if [ -s "$stdout_file" ]; then
        cat "$stdout_file"
    else
        echo "(none)"
    fi
    echo

    # Print stderr
    echo "Stderr:"
    if [ -s "$stderr_file" ]; then
        cat "$stderr_file"
    else
        echo "(none)"
    fi
    echo

    # Print exit code
    echo "Exit Code: $exit_code"

    # Clean up temporary files
    rm -f "$stdout_file" "$stderr_file"
}


# Example function that outputs to stdout and stderr
noisy_function() {
    echo "This goes to stdout"
    echo "This goes to stderr" >&2
}

# Test the eval_with_output function
eval_with_output "noisy_function"
eval_with_output "noisy_function; echo Extra output"


eval_with_output() {
    local input_string="$1"
    local stdout_file stderr_file exit_code

    # Create temporary files for stdout and stderr
    stdout_file=$(mktemp)
    stderr_file=$(mktemp)

    # Print the code being executed
    echo "Code:"
    echo "$input_string"
    echo

    # Evaluate the string in a subshell, capturing stdout and stderr
    (
        exec >"$stdout_file" 2>"$stderr_file"
        eval "$input_string"
    )
    exit_code=$?

    # Print stdout
    echo "Stdout:"
    if [ -s "$stdout_file" ]; then
        cat "$stdout_file"
    else
        echo "(none)"
    fi
    echo

    # Print stderr
    echo "Stderr:"
    if [ -s "$stderr_file" ]; then
        cat "$stderr_file"
    else
        echo "(none)"
    fi
    echo

    # Print exit code
    echo "Exit Code: $exit_code"

    # Clean up temporary files
    rm -f "$stdout_file" "$stderr_file"
}



Limitations:
    •  Commands that write to /dev/tty directly can’t be captured this way (rare case).
    •  If the command forks (e.g., background jobs with &), output capture may be incomplete unless managed carefully.
•  Alternative to quiet:
    •  The original quiet function ("$@" >/dev/null) can still be used for complete suppression without capturing output. Use quiet_capture when you want to store the output instead.