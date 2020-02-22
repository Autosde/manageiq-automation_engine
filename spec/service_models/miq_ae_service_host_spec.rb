describe MiqAeMethodService::MiqAeServiceHost do
  before do
    @user = FactoryBot.create(:user_with_group)
    Spec::Support::MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM', 'AUTOMATE', 'test1', 'test')
    @ae_method = ::MiqAeMethod.first
    @ae_result_key = 'foo'
    @host = FactoryBot.create(:host, :ext_management_system => FactoryBot.create(:ext_management_system))
  end

  def invoke_ae
    MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?Host::host=#{@host.id}", @user)
  end

  it "#show_url" do
    ui_url = stub_remote_ui_url

    svc_host = MiqAeMethodService::MiqAeServiceHost.find(@host.id)

    expect(svc_host.show_url).to eq("#{ui_url}/host/show/#{@host.id}")
  end

  context "$evm.vmdb" do
    it "with no parms" do
      method = "$evm.root['#{@ae_result_key}'] = $evm.vmdb('host')"
      @ae_method.update(:data => method)
      ae_result = invoke_ae.root(@ae_result_key)
      expect(ae_result).to eq(MiqAeMethodService::MiqAeServiceHost)

      expect(ae_result.count).to eq(1)

      hosts = ae_result.all
      expect(hosts[0]).to be_kind_of(MiqAeMethodService::MiqAeServiceHost)
      expect(hosts[0].id).to eq(@host.id)

      method = "$evm.root['#{@ae_result_key}'] = $evm.vmdb('host').count"
      @ae_method.update(:data => method)
      ae_result = invoke_ae.root(@ae_result_key)
      expect(ae_result).to eq(1)
    end

    it "with ems_events" do
      @ems_event = FactoryBot.create(:ems_event)
      @host.ems_events << @ems_event
      method = "$evm.root['#{@ae_result_key}'] = $evm.vmdb('host').first.ems_events"
      @ae_method.update(:data => method)
      ae_result = invoke_ae.root(@ae_result_key)
      expect(ae_result.first).to be_kind_of(MiqAeMethodService::MiqAeServiceEmsEvent)
      expect(ae_result.first.id).to eq(@ems_event.id)
    end

    it "with id" do
      method = "$evm.root['#{@ae_result_key}'] = $evm.vmdb('host', #{@host.id})"
      @ae_method.update(:data => method)
      ae_result = invoke_ae.root(@ae_result_key)
      expect(ae_result).to be_kind_of(MiqAeMethodService::MiqAeServiceHost)
      expect(ae_result.id).to eq(@host.id)
    end

    it "with array of ids" do
      method = "$evm.root['#{@ae_result_key}'] = $evm.vmdb('host', [#{@host.id}])"
      @ae_method.update(:data => method)
      ae_result = invoke_ae.root(@ae_result_key)
      expect(ae_result).to be_kind_of(Array)

      hosts = ae_result
      expect(hosts.length).to eq(1)
      expect(hosts[0]).to be_kind_of(MiqAeMethodService::MiqAeServiceHost)
      expect(hosts[0].id).to eq(@host.id)
    end
  end

  it "#ems_custom_keys" do
    method = "$evm.root['#{@ae_result_key}'] = $evm.root['host'].ems_custom_keys"
    @ae_method.update(:data => method)
    ae_result = invoke_ae.root(@ae_result_key)
    expect(ae_result).to be_kind_of(Array)
    expect(ae_result).to be_empty

    key1   = 'key1'
    value1 = 'value1'
    FactoryBot.create(:ems_custom_attribute, :resource => @host, :name => key1, :value => value1)
    ae_result = invoke_ae.root(@ae_result_key)
    expect(ae_result).to be_kind_of(Array)
    expect(ae_result.length).to eq(1)
    expect(ae_result.first).to eq(key1)

    key2   = 'key2'
    value2 = 'value2'
    FactoryBot.create(:ems_custom_attribute, :resource => @host, :name => key2, :value => value2)
    ae_result = invoke_ae.root(@ae_result_key)
    expect(ae_result).to be_kind_of(Array)
    expect(ae_result.length).to eq(2)
    expect(ae_result.sort).to eq([key1, key2])
  end

  it "#ems_custom_get" do
    key    = 'key1'
    value  = 'value1'
    method = "$evm.root['#{@ae_result_key}'] = $evm.root['host'].ems_custom_get('#{key}')"
    @ae_method.update(:data => method)
    ae_result = invoke_ae.root(@ae_result_key)
    expect(ae_result).to be_nil

    FactoryBot.create(:ems_custom_attribute, :resource => @host, :name => key, :value => value)
    ae_result = invoke_ae.root(@ae_result_key)
    expect(ae_result).to eq(value)
  end

  it "#get_realtime_metric" do
    metric   = 'metric1'
    range    = 10.minutes
    function = :max
    method = "$evm.root['#{@ae_result_key}'] =
              $evm.root['host'].get_realtime_metric('#{metric}', #{range}, :#{function})"
    @ae_method.update(:data => method)
    expect_any_instance_of(Host).to receive(:get_performance_metric).with(:realtime, metric, range, function).once
    ae_result = invoke_ae.root(@ae_result_key)
    expect(ae_result).to be_nil
  end

  it "#ems_custom_set async" do
    @base_queue_options = {
      :class_name  => @host.class.name,
      :instance_id => @host.id,
      :zone        => @host.my_zone,
      :role        => 'ems_operations',
      :queue_name  => @host.queue_name_for_ems_operations,
      :task_id     => nil
    }
    svc_host = MiqAeMethodService::MiqAeServiceHost.find(@host.id)
    svc_host.ems_custom_set("thing", "thing1")

    expect(MiqQueue.last).to have_attributes(
      @base_queue_options.merge(
        :method_name => 'set_custom_field',
        :args        => ["thing", "thing1"]
      )
    )
  end
end
