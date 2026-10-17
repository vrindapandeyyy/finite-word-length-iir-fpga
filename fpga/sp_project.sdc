# Timing constraints for the DE2-115 filter project.
# Without this file Quartus assumes a 1.0 ns clock and reports a false violation.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_clock_uncertainty

# Switches, keys and LEDs are human-speed signals: exclude them from timing checks.
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to   [get_ports {LEDR[*] LEDG[*]}]
