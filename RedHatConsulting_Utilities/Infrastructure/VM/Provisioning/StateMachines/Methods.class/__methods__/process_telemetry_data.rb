# Uses time data captured during the VM provisioning process to set custom attributes
# on the VM about the times taken to perform steps of the provisioning process.
#
# Parameters:
# 	ROOT
# 		* miq_provision
#
module RedHatConsulting_Utilities
  module Automate
    module Infrastructure
      module VM
        module Provisioning
          class ProcessTelemetryData
            include RedHatConsulting_Utilities::StdLib::Core

            PROVISIONING_TELEMETRY_PREFIX = "Provisioning_Telemetry"

            def initialize(handle = $evm)
              @handle = handle
              @DEBUG = true
            end

            # Get the duration between two times.
            #
            # @return Duration in HH:MM:SS between to times, or Unknown, if any time is nil
            def get_duration(start_time, end_time)
              @handle.log(:info, "get_duration: START: { :start_time => #{start_time}, :end_time => #{end_time} }") if @DEBUG

              start_time = @handle.get_state_var(start_time) if start_time.class == Symbol
              end_time = @handle.get_state_var(end_time) if end_time.class == Symbol

              duration = if start_time && end_time
                           seconds_to_time(end_time.in_time_zone("UTC") - start_time.in_time_zone("UTC"))
                         else
                           'Unknown'
                         end

              @handle.log(:info, "get_duration: END: { :duration => #{duration}, :start_time => #{start_time}, :end_time => #{end_time} }") if @DEBUG
              duration
            end

            # Set VM custom attribute with provisioning telemetry data
            def set_provisioning_telemetry_custom_attribute(vm, description, value)
              vm.custom_set("#{PROVISIONING_TELEMETRY_PREFIX}_#{description}".gsub('[ :].*', '_'), value)
            end

            def main()
              # Get vm from miq_provision object
              prov = @handle.root['miq_provision']
              vm = prov.vm
              error("VM not found") if vm.nil?

              # determine how long different steps took
              now = Time.now
              duration_task_queue = get_duration(prov.created_on, :vm_provisioning_telemetry_on_entry_CustomizeRequest)
              duration_vm_provisioning = get_duration(:vm_provisioning_telemetry_on_entry_CustomizeRequest, now)
              duration_vm_clone = get_duration(:vm_provisioning_telemetry_on_entry_Provision, :vm_provisioning_telemetry_on_exit_CheckProvisioned)
              duration_wait_for_vm_mac_addresses = get_duration(:vm_provisioning_telemetry_on_entry_WaitForVMMACAddresses, :vm_provisioning_telemetry_on_exit_WaitForVMMACAddresses)
              duration_start_vm = get_duration(:vm_provisioning_telemetry_on_entry_StartVM, :vm_provisioning_telemetry_on_exit_StartVM)
              duration_wait_for_vm_ip_addresses = get_duration(:vm_provisioning_telemetry_on_entry_WaitForVMIPAddresses, :vm_provisioning_telemetry_on_exit_WaitForVMIPAddresses)

              set_provisioning_telemetry_custom_attribute(vm, 'Time_Request_Created', prov.created_on.localtime)
              set_provisioning_telemetry_custom_attribute(vm, 'Time_Request_Completed', now)
              set_provisioning_telemetry_custom_attribute(vm, 'Hour_Request_Created', prov.created_on.localtime.hour)
              set_provisioning_telemetry_custom_attribute(vm, 'Duration_Task_Queue', duration_task_queue)
              set_provisioning_telemetry_custom_attribute(vm, 'Duration_Total_VM_Provisioning', duration_vm_provisioning)
              set_provisioning_telemetry_custom_attribute(vm, 'Duration_VM_Clone', duration_vm_clone)
              set_provisioning_telemetry_custom_attribute(vm, 'Duration_Wait_for_VM_MAC_Addresses', duration_wait_for_vm_mac_addresses)
              set_provisioning_telemetry_custom_attribute(vm, 'Duration_Start_VM', duration_start_vm)
              set_provisioning_telemetry_custom_attribute(vm, 'Duration_Wait_for_VM_IP_Addresses', duration_wait_for_vm_ip_addresses)
            end
          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  RedHatConsulting_Utilities::Automate::Infrastructure::VM::Provisioning::ProcessTelemetryData.new.main()
end
