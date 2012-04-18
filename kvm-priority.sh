#!/bin/bash
# KVM VM Priority - stu@lifeofstu.com

CFG_FILE="/etc/libvirt/vm-priority.cfg"

###################################
## TOUCH NOTHING BELOW THIS LINE ##
###################################

# Error handling
function kvm_error {
  echo "ERROR: $1"
  exit 1
}

# Check the configuration file exists
[ -f "$CFG_FILE" ] || \
  kvm_error "The configuration file '$CFG_FILE' is missing"

# Loop through PID's of running VM's
for vm_pid in $(pidof kvm    2>/dev/null | \
                xargs -n 1   2>/dev/null | \
                sort | xargs 2>/dev/null) ; do
  # Get the priorty value and name of the VM
  vm_prio=$(ps -o nice -p $vm_pid 2>/dev/null | \
            tail -n 1 | sed -e 's/^[^0-9\-]*//g')
  vm_name=$(ps -o cmd  -p $vm_pid 2>/dev/null | \
            tail -n 1 | sed -e 's/^[^0-9a-zA-Z]*//g' | \
            sed -e 's/^.*-name\ \([a-zA-Z0-9]*\).*/\1/' 2>/dev/null)
  # Sanity check
  [ "$vm_prio" != "" ] || \
    kvm_error "Unable to retrieve running VM priority"
  [ "$vm_name" != "" ] || \
    kvm_error "Unable to retrieve running VM name"
  # Inform the user of the details
  printf "PID: %5d   -   PRIO: %3d   -   VM NAME: %s\n" $vm_pid $vm_prio $vm_name
  # Check if a priority level has been configured
  while IFS="|" read vmc_name vmc_prio ; do
    # Is the line a comment
    if [[ "$vmc_name" =~ ^# ]]; then
      # Comment
      continue
    fi
    # Sanity check
    [ "$vmc_name" != "" ] || \
      kvm_error "Found invalid VM name in cfg file"
    [ "$vmc_prio" != "" ] || \
      kvm_error "Found invalid VM priority in cfg file"
    # Check for a match
    if [ "$vmc_name" = "$vm_name" ]; then
      # Match found, check if the priority is different
      if [ "$vmc_prio" != "$vm_prio" ]; then
        echo "  - Changing priority from $vm_prio to $vmc_prio"
        renice -n $vmc_prio -p $vm_pid >/dev/null 2>&1
      else
        echo "  - Priority is correct, no adjustment needed"
      fi
    fi
  done <"$CFG_FILE"
  echo
done

# All done
exit 0
