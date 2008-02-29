# Run a process as a different user
# Thanks to the "Ruby Cookbook" for this one
module Process
  def as_uid(uid=0)
    old_euid, old_uid = Process.euid, Process.uid
    Process.euid, Process.uid = uid, uid
    begin
      yield
    ensure
      Process.euid, Process.uid = old_euid, old_uid
    end
  end
  module_function(:as_uid)
end
