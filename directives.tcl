set sfd [file dirname [file normalize [info script]]]
set input_files "input_files.tcl"
source $sfd/$input_files

foreach file $sources {
    add_file -type vhdl $file
}

puts "Added files..."

set_device -name GW1NR-9 GW1NR-LV9QN88PC6/I5

set_option -vhdl_std vhd2008
set_option -top_module $top_module

run syn