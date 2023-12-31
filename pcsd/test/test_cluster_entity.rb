require 'test/unit'
require 'fileutils'
require 'json'
require 'rexml/document'
require 'set'

require 'pcsd_test_utils.rb'
require 'cluster_entity.rb'

CIB_FILE = 'cib1.xml'

def assert_equal_NvSet(set1, set2)
  set1.each { |pair|
    assert(set2.include?(pair.name), "Expected pair with name #{pair.name}")
    assert(set2[pair.name].id == pair.id, "Id of pair differs. Expected: '#{pair.id}' but was '#{set2[pair.name].id}'")
    assert(set2[pair.name].name == pair.name, "Name of pair differs. Expected: '#{pair.name}' but was '#{set2[pair.name].name}'")
    assert(set2[pair.name].value == pair.value, "Value of pair differs. Expected: '#{pair.value}' but was '#{set2[pair.name].value}'")
  }
  set2.each { |pair|
    assert(set1.include?(pair.name), "Found pair which is not expected (name:'#{pair.name}')")
  }
end

def get_group(entity)
  if entity.parent.instance_of?(ClusterEntity::Group)
    return entity.parent.id
  end
  return nil
end

def get_clone(entity)
  if entity.parent.instance_of?(ClusterEntity::Clone)
    return entity.parent.id
  elsif (entity.parent.instance_of?(ClusterEntity::Group) and
    entity.parent.parent.instance_of?(ClusterEntity::Clone)
  )
    return entity.parent.parent.id
  end
  return nil
end


class TestNvSet < Test::Unit::TestCase
  def setup
    @nvSet = ClusterEntity::NvSet.new
  end

  def test_empty?
    assert(@nvSet.empty?)
    @nvSet << ClusterEntity::NvPair.new(nil, nil)
    assert_equal(false, @nvSet.empty?)
    @nvSet << ClusterEntity::NvPair.new('id', 'name')
    assert_equal(false, @nvSet.empty?)
    @nvSet.delete(nil)
    assert_equal(false, @nvSet.empty?)
    @nvSet.delete('name')
    assert(@nvSet.empty?)
  end

  def test_length
    assert_equal(0, @nvSet.length)
    @nvSet << ClusterEntity::NvPair.new(nil, nil)
    assert_equal(1, @nvSet.length)
    @nvSet << ClusterEntity::NvPair.new('id', 'name')
    assert_equal(2, @nvSet.length)
    @nvSet.delete('name')
    assert_equal(1, @nvSet.length)
    @nvSet.delete(nil)
    assert_equal(0, @nvSet.length)
    @nvSet << ClusterEntity::NvPair.new('id', 'name1')
    @nvSet << ClusterEntity::NvPair.new('id', 'name2')
    @nvSet << ClusterEntity::NvPair.new('id', 'name3')
    @nvSet << ClusterEntity::NvPair.new('id', 'name4')
    assert_equal(4, @nvSet.length)
    @nvSet << ClusterEntity::NvPair.new('id', 'name1', 'val')
    assert_equal(4, @nvSet.length)
  end

  def test_each
    counter = 0
    @nvSet.each { |e|
      counter += 1
    }
    assert_equal(0, counter)
    pair = ClusterEntity::NvPair.new('id1', 'name1')
    @nvSet << pair
    @nvSet.each { |e|
      assert_equal(pair, e)
      counter += 1
    }
    assert_equal(1, counter)
    pairs = [pair]
    pair = ClusterEntity::NvPair.new('id2', 'name2')
    @nvSet << pair
    pairs << pair
    pair = ClusterEntity::NvPair.new('id3', 'name3')
    @nvSet << pair
    pairs << pair
    pairs2 = pairs.dup
    counter = 0
    @nvSet.each { |e|
      assert_equal(pairs.delete(e), e)
      counter += 1
    }
    assert_equal(3, counter)
    pairs2.delete(@nvSet.delete('name2'))
    counter = 0
    @nvSet.each { |e|
      assert_equal(pairs2.delete(e), e)
      counter += 1
    }
    assert_equal(2, counter)
  end

  def test_add
    @nvSet << ClusterEntity::NvPair.new('id1', 'name1', 'value1')
    counter = 0
    @nvSet.each { |e|
      assert_equal('id1', e.id)
      assert_equal('name1', e.name)
      assert_equal('value1', e.value)
      counter += 1
    }
    assert_equal(1, counter)

    @nvSet << ClusterEntity::NvPair.new('id2', 'name2', 'value2')
    map = {
      'id1' => {
        :id => 'id1',
        :name => 'name1',
        :value => 'value1'
      },
      'id2' => {
        :id => 'id2',
        :name => 'name2',
        :value => 'value2'
      }
    }
    counter = 0
    @nvSet.each { |e|
      assert_equal(map[e.id][:id], e.id)
      assert_equal(map[e.id][:name], e.name)
      assert_equal(map[e.id][:value], e.value)
      counter += 1
    }
    assert_equal(2, counter)

    @nvSet << ClusterEntity::NvPair.new('id22', 'name2', 'value22')
    map = {
      'id1' => {
        :id => 'id1',
        :name => 'name1',
        :value => 'value1'
      },
      'id22' => {
        :id => 'id22',
        :name => 'name2',
        :value => 'value22'
      }
    }
    counter = 0
    @nvSet.each { |e|
      assert_equal(map[e.id][:id], e.id)
      assert_equal(map[e.id][:name], e.name)
      assert_equal(map[e.id][:value], e.value)
      counter += 1
    }
    assert_equal(2, counter)

    assert_raise(ArgumentError) {
      @nvSet << "not NvPair"
    }

    assert_raise(ArgumentError) {
      @nvSet << nil
    }
  end

  def test_include?
    assert_equal(false, @nvSet.include?(nil))
    assert_equal(false, @nvSet.include?('name1'))
    assert_equal(false, @nvSet.include?('name2'))
    assert_equal(false, @nvSet.include?('name3'))
    @nvSet << ClusterEntity::NvPair.new('id1', 'name1', 'value1')
    assert_equal(false, @nvSet.include?(nil))
    assert(@nvSet.include?('name1'))
    assert_equal(false, @nvSet.include?('name2'))
    assert_equal(false, @nvSet.include?('name3'))
    @nvSet << ClusterEntity::NvPair.new('id2', 'name2', 'value2')
    assert_equal(false, @nvSet.include?(nil))
    assert(@nvSet.include?('name1'))
    assert(@nvSet.include?('name2'))
    assert_equal(false, @nvSet.include?('name3'))
    @nvSet << ClusterEntity::NvPair.new('id22', 'name2', 'value22')
    assert_equal(false, @nvSet.include?(nil))
    assert(@nvSet.include?('name1'))
    assert(@nvSet.include?('name2'))
    assert_equal(false, @nvSet.include?('name3'))
  end

  def test_indexer
    assert_nil(@nvSet[nil])
    assert_nil(@nvSet['name1'])
    @nvSet << ClusterEntity::NvPair.new('id1', 'name1', 'value1')
    assert_nil(@nvSet[nil])
    assert_nil(@nvSet['name2'])
    assert_equal('id1', @nvSet['name1'].id)
    assert_equal('name1', @nvSet['name1'].name)
    assert_equal('value1', @nvSet['name1'].value)
    @nvSet << ClusterEntity::NvPair.new('id2', 'name2', 'value2')
    assert_equal('id1', @nvSet['name1'].id)
    assert_equal('name1', @nvSet['name1'].name)
    assert_equal('value1', @nvSet['name1'].value)
    assert_equal('id2', @nvSet['name2'].id)
    assert_equal('name2', @nvSet['name2'].name)
    assert_equal('value2', @nvSet['name2'].value)
    assert_nil(@nvSet[nil])
    assert_nil(@nvSet['name3'])
  end

  def test_delete
    assert_nil(@nvSet.delete(nil))
    assert_nil(@nvSet.delete('name1'))
    @nvSet << ClusterEntity::NvPair.new('id1', 'name1', 'value1')
    @nvSet << ClusterEntity::NvPair.new('id2', 'name2', 'value2')
    @nvSet << ClusterEntity::NvPair.new('id3', 'name3', 'value3')
    p = @nvSet.delete('name2')
    assert_equal(false, @nvSet.include?('name2'))
    assert_equal('id2', p.id)
    assert_equal('name2', p.name)
    assert_equal('value2', p.value)
    assert(@nvSet.include?('name1'))
    assert(@nvSet.include?('name3'))
    @nvSet.delete('name3')
    assert_equal(false, @nvSet.include?('name3'))
    assert_nil(@nvSet.delete('name2'))
  end
end


module TestResourceStatusMixin
  def test_init
    s = ClusterEntity::CRMResourceStatus.new(@crm_mon.elements["//resource[@id='dummy1']"])
    assert_equal('dummy1', s.id)
    assert_equal('ocf::heartbeat:Dummy', s.resource_agent)
    assert(s.managed)
    assert_equal(false, s.failed)
    assert_equal('Started', s.role)
    assert(s.active)
    assert_equal(false, s.orphaned)
    assert_equal(false, s.failure_ignored)
    assert_equal(s.nodes_running_on, 1)
    assert_nil(s.pending)
    assert_equal(false, s.blocked)
    assert_nil(s.target_role)
    node = {
      :name => 'node1',
      :id => '1',
      :cached => false
    }
    assert(node == s.node)
  end

  def test_init_blocked_and_target_role
    s = ClusterEntity::CRMResourceStatus.new(@crm_mon.elements["//resource[@id='dummy2']"])
    assert_equal('dummy2', s.id)
    assert_equal('ocf::heartbeat:Dummy', s.resource_agent)
    assert(s.managed)
    assert_equal(false, s.failed)
    assert_equal('Stopped', s.role)
    assert_equal(false, s.active)
    assert_equal(false, s.orphaned)
    assert_equal(false, s.failure_ignored)
    assert_equal(s.nodes_running_on, 0)
    assert_nil(s.pending)
    assert_equal(true, s.blocked)
    assert_equal('Started', s.target_role)
    assert_nil(s.node)
  end

  def test_init_roles_promotable
    s = ClusterEntity::CRMResourceStatus.new(@crm_mon.elements["//resource[@id='ms']"])
    assert_equal('ms', s.id)
    assert_equal('ocf::pacemaker:Stateful', s.resource_agent)
    assert_equal('Master', s.role)
    assert_nil(s.target_role)
    assert_equal(
      {
        :name => 'node3',
        :id => '3',
        :cached => false
      },
      s.node
    )
  end

  def test_init_invalid_element
    xml = "<primitive id='dummy1'/>"
    s = ClusterEntity::CRMResourceStatus.new(REXML::Document.new(xml))
    assert_nil(s.id)
    assert_nil(s.resource_agent)
    assert_equal(false, s.managed)
    assert_equal(false, s.failed)
    assert_nil(s.role)
    assert_equal(false, s.active)
    assert_equal(false, s.orphaned)
    assert_equal(false, s.failure_ignored)
    assert_equal(s.nodes_running_on, 0)
    assert_nil(s.pending)
    assert_nil(s.node)
  end
end

class TestResourceStatusCrmMon1 < Test::Unit::TestCase

  include TestResourceStatusMixin

  def setup
    @cib = REXML::Document.new(File.read(File.join(CURRENT_DIR, CIB_FILE)))
    @crm_mon = REXML::Document.new(File.read(File.join(CURRENT_DIR, 'crm1.xml')))
  end
end

class TestResourceStatusCrmMon2 < Test::Unit::TestCase

  include TestResourceStatusMixin

  def setup
    @cib = REXML::Document.new(File.read(File.join(CURRENT_DIR, CIB_FILE)))
    @crm_mon = REXML::Document.new(File.read(File.join(CURRENT_DIR, 'crm2.xml')))
  end
end

class TestResourceStatusCrmMon2NewRoles < Test::Unit::TestCase

  include TestResourceStatusMixin

  def setup
    @cib = REXML::Document.new(File.read(File.join(CURRENT_DIR, CIB_FILE)))
    @crm_mon = REXML::Document.new(File.read(File.join(CURRENT_DIR, 'crm2_new_roles.xml')))
  end
end

class TestResourceOperation < Test::Unit::TestCase
  def setup
    @cib = REXML::Document.new(File.read(File.join(CURRENT_DIR, CIB_FILE)))
  end

  def test_init
    o = ClusterEntity::ResourceOperation.new(@cib.elements["//lrm_rsc_op[@id='dummy1_last_0']"])
    assert_equal(123, o.call_id)
    assert_equal('build_active_RAs', o.crm_debug_origin)
    assert_equal('3.0.9', o.crm_feature_set)
    assert_equal(21, o.exec_time)
    assert_nil(o.exit_reason)
    assert_equal('dummy1_last_0', o.id)
    assert_equal(0, o.interval)
    assert_equal(1436002943, o.last_rc_change)
    assert_equal(1436002943, o.last_run)
    assert_equal('node3', o.on_node)
    assert_equal('07c70cdfaab292cf9afd6ca7c583b7ff', o.op_digest)
    assert_equal('dummy1_stop_0', o.operation_key)
    assert_equal('stop', o.operation)
    assert_nil(o.op_force_restart)
    assert_nil(o.op_restart_digest)
    assert_equal(0, o.op_status)
    assert_equal(0, o.queue_time)
    assert_equal(0, o.rc_code)
    assert_equal('36:2:0:c4cdc0be-a153-421e-b1f9-d78eee41c0b6', o.transition_key)
    assert_equal('0:0;36:2:0:c4cdc0be-a153-421e-b1f9-d78eee41c0b6', o.transition_magic)
  end
end


module TestPrimitiveMixin
  def test_init
    obj = ClusterEntity::Primitive.new(@cib.elements["//primitive[@id='dummy1']"])
    assert_nil(obj.parent)
    assert_nil(get_group(obj))
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'dummy1-meta_attributes-testattr',
      'testattr',
      '0'
    ) << ClusterEntity::NvPair.new(
      'dummy1-meta_attributes-attr2',
      'attr2',
      '10'
    )
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    utilization = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'dummy1-utilization-test_name',
      'test_name',
      '-10'
    ) << ClusterEntity::NvPair.new(
      'dummy1-utilization-another_one',
      'another_one',
      '0'
    )
    assert_equal_NvSet(utilization, obj.utilization)
    assert_equal('dummy1', obj.id)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_equal('ocf::heartbeat:Dummy', obj.agentname)
    assert_equal('ocf', obj._class)
    assert_equal('heartbeat', obj.provider)
    assert_equal('Dummy', obj.type)
    assert_equal(false, obj.stonith)
    instance_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'dummy1-instance_attributes-fake',
      'fake',
      '--test'
    )
    assert_equal_NvSet(instance_attr, obj.instance_attr)
    assert(obj.crm_status.empty?)
    assert(obj.operations.empty?)
  end

  def test_init_with_crm
    obj = ClusterEntity::Primitive.new(
      @cib.elements["//primitive[@id='dummy1']"],
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    assert_nil(obj.parent)
    assert_nil(get_group(obj))
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'dummy1-meta_attributes-testattr',
      'testattr',
      '0'
    ) << ClusterEntity::NvPair.new(
      'dummy1-meta_attributes-attr2',
      'attr2',
      '10'
    )
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    utilization = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'dummy1-utilization-test_name',
      'test_name',
      '-10'
    ) << ClusterEntity::NvPair.new(
      'dummy1-utilization-another_one',
      'another_one',
      '0'
    )
    assert_equal_NvSet(utilization, obj.utilization)
    assert_equal('dummy1', obj.id)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_equal('ocf::heartbeat:Dummy', obj.agentname)
    assert_equal('ocf', obj._class)
    assert_equal('heartbeat', obj.provider)
    assert_equal('Dummy', obj.type)
    assert_equal(false, obj.stonith)
    instance_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'dummy1-instance_attributes-fake',
      'fake',
      '--test'
    )
    assert_equal_NvSet(instance_attr, obj.instance_attr)
    assert(obj.operations.empty?)
    assert_equal(1, obj.crm_status.length)

    # ResourceStatus
    s = obj.crm_status[0]
    assert_instance_of(ClusterEntity::CRMResourceStatus, s)
    assert_equal('dummy1', s.id)
    assert_equal('ocf::heartbeat:Dummy', s.resource_agent)
    assert(s.managed)
    assert_equal(false, s.failed)
    assert_equal('Started', s.role)
    assert(s.active)
    assert_equal(false, s.orphaned)
    assert_equal(false, s.failure_ignored)
    assert_equal(s.nodes_running_on, 1)
    assert_nil(s.pending)
    node = {
      :name => 'node1',
      :id => '1',
      :cached => false
    }
    assert(node == s.node)
  end

  def test_init_with_crm_and_operations
    obj = ClusterEntity::Primitive.new(
      @cib.elements["//primitive[@id='dummy1']"],
      ClusterEntity::get_rsc_status(@crm_mon),
      nil,
      ClusterEntity::get_resources_operations(@cib)
    )
    assert_nil(obj.parent)
    assert_nil(get_group(obj))
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'dummy1-meta_attributes-testattr',
      'testattr',
      '0'
    ) << ClusterEntity::NvPair.new(
      'dummy1-meta_attributes-attr2',
      'attr2',
      '10'
    )
    utilization = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'dummy1-utilization-test_name',
      'test_name',
      '-10'
    ) << ClusterEntity::NvPair.new(
      'dummy1-utilization-another_one',
      'another_one',
      '0'
    )
    assert_equal_NvSet(utilization, obj.utilization)
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    assert_equal('dummy1', obj.id)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_equal('ocf::heartbeat:Dummy', obj.agentname)
    assert_equal('ocf', obj._class)
    assert_equal('heartbeat', obj.provider)
    assert_equal('Dummy', obj.type)
    assert_equal(false, obj.stonith)
    instance_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'dummy1-instance_attributes-fake',
      'fake',
      '--test'
    )
    assert_equal_NvSet(instance_attr, obj.instance_attr)
    assert_equal(1, obj.crm_status.length)
    assert_equal(4, obj.operations.length)

    # ResourceStatus
    s = obj.crm_status[0]
    assert_instance_of(ClusterEntity::CRMResourceStatus, s)
    assert_equal('dummy1', s.id)
    assert_equal('ocf::heartbeat:Dummy', s.resource_agent)
    assert(s.managed)
    assert_equal(false, s.failed)
    assert_equal('Started', s.role)
    assert(s.active)
    assert_equal(false, s.orphaned)
    assert_equal(false, s.failure_ignored)
    assert_equal(s.nodes_running_on, 1)
    assert_nil(s.pending)
    node = {
      :name => 'node1',
      :id => '1',
      :cached => false
    }
    assert(node == s.node)

    # ResourceOperation
    assert_equal('running', obj.status.to_s)
    o = obj.operations[0]
    assert_instance_of(ClusterEntity::ResourceOperation, o)
    assert_equal(123, o.call_id)
    assert_equal('build_active_RAs', o.crm_debug_origin)
    assert_equal('3.0.9', o.crm_feature_set)
    assert_equal(21, o.exec_time)
    assert_nil(o.exit_reason)
    assert_equal('dummy1_last_0', o.id)
    assert_equal(0, o.interval)
    assert_equal(1436002943, o.last_rc_change)
    assert_equal(1436002943, o.last_run)
    assert_equal('node3', o.on_node)
    assert_equal('07c70cdfaab292cf9afd6ca7c583b7ff', o.op_digest)
    assert_equal('dummy1_stop_0', o.operation_key)
    assert_equal('stop', o.operation)
    assert_nil(o.op_force_restart)
    assert_nil(o.op_restart_digest)
    assert_equal(0, o.op_status)
    assert_equal(0, o.queue_time)
    assert_equal(0, o.rc_code)
    assert_equal('36:2:0:c4cdc0be-a153-421e-b1f9-d78eee41c0b6', o.transition_key)
    assert_equal('0:0;36:2:0:c4cdc0be-a153-421e-b1f9-d78eee41c0b6', o.transition_magic)

    o = obj.operations[1]
    assert_instance_of(ClusterEntity::ResourceOperation, o)
    assert_equal('dummy1_last_0', o.id)
    assert_equal('16d989b809c6743cad46d0d12b8a9262', o.op_digest)

    o = obj.operations[2]
    assert_instance_of(ClusterEntity::ResourceOperation, o)
    assert_equal('dummy1_monitor_10000', o.id)
    assert_equal('c94db5a1993f190ecfd975fd8fe499b3', o.op_digest)

    o = obj.operations[3]
    assert_instance_of(ClusterEntity::ResourceOperation, o)
    assert_equal('dummy1_last_0', o.id)
    assert_equal('07c70cdfaab292cf9afd6ca7c583b7ff', o.op_digest)
  end

  def test_init_with_operations
    obj = ClusterEntity::Primitive.new(
      @cib.elements["//primitive[@id='dummy1']"],
      nil,
      nil,
      ClusterEntity::get_resources_operations(@cib)
    )
    assert_nil(obj.parent)
    assert_nil(get_group(obj))
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'dummy1-meta_attributes-testattr',
      'testattr',
      '0'
    ) << ClusterEntity::NvPair.new(
      'dummy1-meta_attributes-attr2',
      'attr2',
      '10'
    )
    utilization = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'dummy1-utilization-test_name',
      'test_name',
      '-10'
    ) << ClusterEntity::NvPair.new(
      'dummy1-utilization-another_one',
      'another_one',
      '0'
    )
    assert_equal_NvSet(utilization, obj.utilization)
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    assert_equal('dummy1', obj.id)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_equal('ocf::heartbeat:Dummy', obj.agentname)
    assert_equal('ocf', obj._class)
    assert_equal('heartbeat', obj.provider)
    assert_equal('Dummy', obj.type)
    assert_equal(false, obj.stonith)
    instance_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'dummy1-instance_attributes-fake',
      'fake',
      '--test'
    )
    assert_equal_NvSet(instance_attr, obj.instance_attr)
    assert(obj.crm_status.empty?)
    assert_equal(4, obj.operations.length)

    # ResourceOperation
    o = obj.operations[0]
    assert_instance_of(ClusterEntity::ResourceOperation, o)
    assert_equal('dummy1_last_0', o.id)
    assert_equal(123, o.call_id)
    assert_equal('build_active_RAs', o.crm_debug_origin)
    assert_equal('3.0.9', o.crm_feature_set)
    assert_equal(21, o.exec_time)
    assert_nil(o.exit_reason)
    assert_equal('dummy1_last_0', o.id)
    assert_equal(0, o.interval)
    assert_equal(1436002943, o.last_rc_change)
    assert_equal(1436002943, o.last_run)
    assert_equal('node3', o.on_node)
    assert_equal('07c70cdfaab292cf9afd6ca7c583b7ff', o.op_digest)
    assert_equal('dummy1_stop_0', o.operation_key)
    assert_equal('stop', o.operation)
    assert_nil(o.op_force_restart)
    assert_nil(o.op_restart_digest)
    assert_equal(0, o.op_status)
    assert_equal(0, o.queue_time)
    assert_equal(0, o.rc_code)
    assert_equal('36:2:0:c4cdc0be-a153-421e-b1f9-d78eee41c0b6', o.transition_key)
    assert_equal('0:0;36:2:0:c4cdc0be-a153-421e-b1f9-d78eee41c0b6', o.transition_magic)

    o = obj.operations[1]
    assert_instance_of(ClusterEntity::ResourceOperation, o)
    assert_equal('dummy1_last_0', o.id)
    assert_equal('16d989b809c6743cad46d0d12b8a9262', o.op_digest)

    o = obj.operations[2]
    assert_instance_of(ClusterEntity::ResourceOperation, o)
    assert_equal('dummy1_monitor_10000', o.id)
    assert_equal('c94db5a1993f190ecfd975fd8fe499b3', o.op_digest)

    o = obj.operations[3]
    assert_instance_of(ClusterEntity::ResourceOperation, o)
    assert_equal('dummy1_last_0', o.id)
    assert_equal('07c70cdfaab292cf9afd6ca7c583b7ff', o.op_digest)
  end

  def test_init_nil
    obj = ClusterEntity::Primitive.new(nil, nil, 'parent', nil)
    assert_equal('parent', obj.parent)
    assert_nil(get_group(obj))
    assert(obj.meta_attr.empty?)
    assert_nil(obj.id)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_nil(obj.agentname)
    assert_nil(obj._class)
    assert_nil(obj.provider)
    assert_nil(obj.type)
    assert_equal(false, obj.stonith)
    assert(obj.instance_attr.empty?)
    assert(obj.crm_status.empty?)
    assert(obj.operations.empty?)
  end

  def test_init_invalid_element
    xml ='<empty_document/>'
    obj = ClusterEntity::Primitive.new(REXML::Document.new(xml))
    assert_nil(obj.parent)
    assert_nil(get_group(obj))
    assert(obj.meta_attr.empty?)
    assert_nil(obj.id)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_nil(obj.agentname)
    assert_nil(obj._class)
    assert_nil(obj.provider)
    assert_nil(obj.type)
    assert_equal(false, obj.stonith)
    assert(obj.instance_attr.empty?)
    assert(obj.crm_status.empty?)
    assert(obj.operations.empty?)
  end

  def test_init_empty_element
    xml ='<primitive/>'
    obj = ClusterEntity::Primitive.new(REXML::Document.new(xml).elements['primitive'])
    assert_nil(obj.parent)
    assert_nil(get_group(obj))
    assert(obj.meta_attr.empty?)
    assert_nil(obj.id)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_nil(obj.agentname)
    assert_nil(obj._class)
    assert_nil(obj.provider)
    assert_nil(obj.type)
    assert_equal(false, obj.stonith)
    assert(obj.instance_attr.empty?)
    assert(obj.crm_status.empty?)
    assert(obj.operations.empty?)
  end

  def test_init_empty_element_with_crm
    xml ='<primitive/>'
    obj = ClusterEntity::Primitive.new(
      REXML::Document.new(xml).elements['primitive'],
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    assert_nil(obj.parent)
    assert_nil(get_group(obj))
    assert(obj.meta_attr.empty?)
    assert_nil(obj.id)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_nil(obj.agentname)
    assert_nil(obj._class)
    assert_nil(obj.provider)
    assert_nil(obj.type)
    assert_equal(false, obj.stonith)
    assert(obj.instance_attr.empty?)
    assert(obj.crm_status.empty?)
    assert(obj.operations.empty?)
  end

  def test_init_stonith
    obj = ClusterEntity::Primitive.new(@cib.elements["//primitive[@id='node1-stonith']"])
    assert_nil(obj.parent)
    assert_nil(get_group(obj))
    assert(obj.meta_attr.empty?)
    assert_equal('node1-stonith', obj.id)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_equal('stonith:fence_xvm', obj.agentname)
    assert_equal('stonith', obj._class)
    assert_nil(obj.provider)
    assert_equal('fence_xvm', obj.type)
    assert(obj.stonith)
    instance_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'node1-stonith-instance_attributes-domain',
      'domain',
      'node1'
    )
    assert_equal_NvSet(instance_attr, obj.instance_attr)
    assert(obj.crm_status.empty?)
    assert(obj.operations.empty?)
  end

  def test_init_stonith_with_warnings
    obj = ClusterEntity::Primitive.new(
      @cib.elements["//primitive[@id='node2-stonith']"]
    )
    assert_nil(obj.parent)
    assert_nil(get_group(obj))
    assert(obj.meta_attr.empty?)
    assert_equal('node2-stonith', obj.id)
    assert(obj.error_list.empty?)
    assert_equal(
      obj.warning_list,
      [
        {
          :message => (
            'This fence-device has the "action" option set, it is ' +
            'recommended to set "pcmk_off_action", "pcmk_reboot_action" instead'
          )
        },
        {
          :message => (
            'This fence-device has the "method" option set to "cycle" which ' +
            'is potentially dangerous, please consider using "onoff"'
          )
        }
      ]
    )
    assert_equal('stonith:fence_xvm', obj.agentname)
    assert_equal('stonith', obj._class)
    assert_nil(obj.provider)
    assert_equal('fence_xvm', obj.type)
    assert(obj.stonith)
    instance_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'node2-stonith-instance_attributes-domain',
      'domain',
      'node2'
    )
    instance_attr << ClusterEntity::NvPair.new(
      'node2-stonith-instance_attributes-action',
      'action',
      'monitor'
    )
    instance_attr << ClusterEntity::NvPair.new(
      'node2-stonith-instance_attributes-method',
      'method',
      'cycle'
    )
    assert_equal_NvSet(instance_attr, obj.instance_attr)
    assert(obj.crm_status.empty?)
    assert(obj.operations.empty?)
  end

  def test_init_stonith_with_crm
    obj = ClusterEntity::Primitive.new(
      @cib.elements["//primitive[@id='node1-stonith']"],
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    assert_nil(obj.parent)
    assert_nil(get_group(obj))
    assert(obj.meta_attr.empty?)
    assert_equal('node1-stonith', obj.id)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_equal('stonith:fence_xvm', obj.agentname)
    assert_equal('stonith', obj._class)
    assert_nil(obj.provider)
    assert_equal('fence_xvm', obj.type)
    assert(obj.stonith)
    instance_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'node1-stonith-instance_attributes-domain',
      'domain',
      'node1'
    )
    assert_equal_NvSet(instance_attr, obj.instance_attr)
    assert(obj.operations.empty?)

    # ResourceStatus
    s = obj.crm_status[0]
    assert_equal('node1-stonith', s.id)
    assert_equal('stonith:fence_xvm', s.resource_agent)
    assert(s.managed)
    assert_equal(false, s.failed)
    assert_equal('Started', s.role)
    assert(s.active)
    assert_equal(false, s.orphaned)
    assert_equal(false, s.failure_ignored)
    assert_equal(s.nodes_running_on, 1)
    assert_nil(s.pending)
    node = {
      :name => 'node3',
      :id => '3',
      :cached => false
    }
    assert(node == s.node)
  end

  def test_to_status_version1
    obj = ClusterEntity::Primitive.new(
      @cib.elements["//primitive[@id='dummy1']"],
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    assert({} == obj.to_status)
  end

  def test_to_status_version1_no_crm
    obj = ClusterEntity::Primitive.new(@cib.elements["//primitive[@id='dummy1']"])
    assert({} == obj.to_status)
  end

  def test_to_status_version2
    obj = ClusterEntity::Primitive.new(
      @cib.elements["//primitive[@id='dummy1']"],
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    json = '{
      "id": "dummy1",
      "meta_attr": [
        {
          "id": "dummy1-meta_attributes-testattr",
          "name": "testattr",
          "value": "0"
        },
        {
          "id": "dummy1-meta_attributes-attr2",
          "name": "attr2",
          "value": "10"
        }
      ],
      "utilization": [
        {
          "id": "dummy1-utilization-test_name",
          "name": "test_name",
          "value": "-10"
        },
        {
          "id": "dummy1-utilization-another_one",
          "name": "another_one",
          "value": "0"
        }
      ],
      "error_list": [],
      "warning_list": [],
      "class_type": "primitive",
      "parent_id": null,
      "disabled": false,
      "agentname": "ocf::heartbeat:Dummy",
      "provider": "heartbeat",
      "type": "Dummy",
      "stonith": false,
      "instance_attr": [
        {
          "id": "dummy1-instance_attributes-fake",
          "name": "fake",
          "value": "--test"
        }
      ],
      "status": "running",
      "class": "ocf",
      "crm_status": [
        {
          "id": "dummy1",
          "resource_agent": "ocf::heartbeat:Dummy",
          "managed": true,
          "failed": false,
          "role": "Started",
          "active": true,
          "orphaned": false,
          "failure_ignored": false,
          "nodes_running_on": 1,
          "pending": null,
          "blocked": false,
          "target_role": null,
          "node": {
            "name": "node1",
            "id": "1",
            "cached": false
          }
        }
      ],
      "operations": []
    }'
    hash = JSON.parse(json, {:symbolize_names => true})
    # assert_equal_hashes(hash, obj.to_status('2'))
    assert(hash == obj.to_status('2'))
  end

  def test_to_status_version2_blocked_and_target_role
    obj = ClusterEntity::Primitive.new(
      @cib.elements["//primitive[@id='dummy2']"],
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    json = '{
      "id": "dummy2",
      "meta_attr": [],
      "utilization": [],
      "error_list": [],
      "warning_list": [],
      "class_type": "primitive",
      "parent_id": null,
      "disabled": false,
      "agentname": "ocf::heartbeat:Dummy",
      "provider": "heartbeat",
      "type": "Dummy",
      "stonith": false,
      "instance_attr": [
      ],
      "status": "blocked",
      "class": "ocf",
      "crm_status": [
        {
          "id": "dummy2",
          "resource_agent": "ocf::heartbeat:Dummy",
          "managed": true,
          "failed": false,
          "role": "Stopped",
          "active": false,
          "orphaned": false,
          "failure_ignored": false,
          "nodes_running_on": 0,
          "pending": null,
          "blocked": true,
          "target_role": "Started",
          "node": null
        }
      ],
      "operations": []
    }'
    hash = JSON.parse(json, {:symbolize_names => true})
    # assert_equal_hashes(hash, obj.to_status('2'))
    assert(hash == obj.to_status('2'))
  end
end

class TestPrimitiveCrmMon1 < Test::Unit::TestCase

  include TestPrimitiveMixin

  def setup
    @cib = REXML::Document.new(File.read(File.join(CURRENT_DIR, CIB_FILE)))
    @crm_mon = REXML::Document.new(File.read(File.join(CURRENT_DIR, 'crm1.xml')))
  end
end

class TestPrimitiveCrmMon2 < Test::Unit::TestCase

  include TestPrimitiveMixin

  def setup
    @cib = REXML::Document.new(File.read(File.join(CURRENT_DIR, CIB_FILE)))
    @crm_mon = REXML::Document.new(File.read(File.join(CURRENT_DIR, 'crm2.xml')))
  end
end


module TestGroupMixin
  def test_init
    obj = ClusterEntity::Group.new(@cib.elements["//group[@id='group1']"])
    assert_equal('group1', obj.id)
    assert_nil(obj.parent)
    assert_nil(get_group(obj))
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'group1-meta_attributes-c',
      'c',
      '1'
    ) << ClusterEntity::NvPair.new(
      'group1-meta_attributes-aaa',
      'aaa',
      '333'
    )
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_equal(2, obj.members.length)
    m = obj.members
    assert_instance_of(ClusterEntity::Primitive, m[0])
    assert_equal(obj.id, get_group(m[0]))
    assert_equal('dummy3', m[0].id)
    assert_equal(obj, m[0].parent)
    assert(m[0].crm_status.empty?)
    assert_instance_of(ClusterEntity::Primitive, m[1])
    assert_equal(obj.id, get_group(m[1]))
    assert_equal('dummy4', m[1].id)
    assert_equal(obj, m[1].parent)
    assert(m[1].crm_status.empty?)
  end

  def test_init_with_crm
    obj = ClusterEntity::Group.new(
      @cib.elements["//group[@id='group1']"],
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    assert_equal('group1', obj.id)
    assert_nil(obj.parent)
    assert_nil(get_group(obj))
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'group1-meta_attributes-c',
      'c',
      '1'
    ) << ClusterEntity::NvPair.new(
      'group1-meta_attributes-aaa',
      'aaa',
      '333'
    )
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_equal(2, obj.members.length)

    m = obj.members
    assert_instance_of(ClusterEntity::Primitive, m[0])
    assert_instance_of(ClusterEntity::Primitive, m[1])
    assert_equal('dummy3', m[0].id)
    assert_equal(obj, m[0].parent)
    assert_equal('dummy4', m[1].id)
    assert_equal(obj, m[1].parent)
    assert_equal(1, m[0].crm_status.length)
    assert_equal(1, m[1].crm_status.length)
    assert_equal(obj.id, get_group(m[0]))
    assert_equal(obj.id, get_group(m[1]))
  end

  def test_init_invalid_element
    xml = '<primitive id="dummy1"/>'
    obj = ClusterEntity::Group.new(REXML::Document.new(xml).elements['*'])
    assert_nil(obj.id)
    assert_nil(obj.parent)
    assert_nil(get_group(obj))
    assert(obj.meta_attr.empty?)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert(obj.members.empty?)
  end

  def test_init_empty_element
    xml = '<group id="group"/>'
    obj = ClusterEntity::Group.new(REXML::Document.new(xml).elements['*'])
    assert_equal('group', obj.id)
    assert_nil(obj.parent)
    assert_nil(get_group(obj))
    assert(obj.meta_attr.empty?)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert(obj.members.empty?)
  end

  def test_to_status_version1
    obj = ClusterEntity::Group.new(
      @cib.elements["//group[@id='group1']"],
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    assert([] == obj.to_status)
  end

  def test_to_status_version2
    obj = ClusterEntity::Group.new(
      @cib.elements["//group[@id='group1']"],
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    json = '{
      "id": "group1",
      "meta_attr": [
        {
          "id": "group1-meta_attributes-c",
          "name": "c",
          "value": "1"
        },
        {
          "id": "group1-meta_attributes-aaa",
          "name": "aaa",
          "value": "333"
        }
      ],
      "error_list": [],
      "warning_list": [],
      "class_type": "group",
      "parent_id": null,
      "disabled": false,
      "status": "running",
      "members": [
        {
          "id": "dummy3",
          "meta_attr": [
            {
              "id": "dummy3-meta_attributes-aaa",
              "name": "aaa",
              "value": "111"
            },
            {
              "id": "dummy3-meta_attributes-b",
              "name": "b",
              "value": "3"
            }
          ],
          "utilization": [],
          "error_list": [],
          "warning_list": [],
          "class_type": "primitive",
          "parent_id": "group1",
          "disabled": false,
          "agentname": "ocf::heartbeat:Dummy",
          "provider": "heartbeat",
          "type": "Dummy",
          "stonith": false,
          "instance_attr": [],
          "status": "running",
          "class": "ocf",
          "crm_status": [
            {
              "id": "dummy3",
              "resource_agent": "ocf::heartbeat:Dummy",
              "managed": true,
              "failed": false,
              "role": "Started",
              "active": true,
              "orphaned": false,
              "failure_ignored": false,
              "nodes_running_on": 1,
              "pending": null,
              "blocked": false,
              "target_role": null,
              "node": {
                "name": "node3",
                "id": "3",
                "cached": false
              }
            }
          ],
          "operations": []
        },
        {
          "id": "dummy4",
          "meta_attr": [
            {
              "id": "dummy4-meta_attributes-aaa",
              "name": "aaa",
              "value": "222"
            },
            {
              "id": "dummy4-meta_attributes-b",
              "name": "b",
              "value": "4"
            }
          ],
          "utilization": [],
          "error_list": [],
          "warning_list": [],
          "class_type": "primitive",
          "parent_id": "group1",
          "disabled": false,
          "agentname": "ocf::heartbeat:Dummy",
          "provider": "heartbeat",
          "type": "Dummy",
          "stonith": false,
          "instance_attr": [],
          "status": "running",
          "class": "ocf",
          "crm_status": [
            {
              "id": "dummy4",
              "resource_agent": "ocf::heartbeat:Dummy",
              "managed": true,
              "failed": false,
              "role": "Started",
              "active": true,
              "orphaned": false,
              "failure_ignored": false,
              "nodes_running_on": 1,
              "pending": null,
              "blocked": false,
              "target_role": null,
              "node": {
                "name": "node3",
                "id": "3",
                "cached": false
              }
            }
          ],
          "operations": []
        }
      ]
    }'
    hash = JSON.parse(json, {:symbolize_names => true})
    assert(hash == obj.to_status('2'))
  end
end

class TestGroupCrmMon1 < Test::Unit::TestCase

  include TestGroupMixin

  def setup
    @cib = REXML::Document.new(File.read(File.join(CURRENT_DIR, CIB_FILE)))
    @crm_mon = REXML::Document.new(File.read(File.join(CURRENT_DIR, 'crm1.xml')))
  end
end

class TestGroupCrmMon2 < Test::Unit::TestCase

  include TestGroupMixin

  def setup
    @cib = REXML::Document.new(File.read(File.join(CURRENT_DIR, CIB_FILE)))
    @crm_mon = REXML::Document.new(File.read(File.join(CURRENT_DIR, 'crm2.xml')))
  end
end


module TestCloneMixin
  def test_init_invalid_element
    xml = '<primitve id="dummy"/>'
    obj = ClusterEntity::Clone.new(REXML::Document.new(xml).elements['*'])
    assert_nil(obj.id)
    assert_nil(obj.parent)
    assert_nil(get_clone(obj))
    assert_nil(get_group(obj))
    assert(obj.meta_attr.empty?)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_nil(obj.member)
    assert_equal(false, obj.unique)
    assert_equal(false, obj.managed)
    assert_equal(false, obj.failed)
    assert_equal(false, obj.failure_ignored)
    assert_equal(false, obj.promotable)
  end

  def test_init_empty_element
    xml = '<clone id="dummy-clone"/>'
    obj = ClusterEntity::Clone.new(REXML::Document.new(xml).elements['*'])
    assert_equal('dummy-clone', obj.id)
    assert_nil(obj.parent)
    assert_nil(get_clone(obj))
    assert_nil(get_group(obj))
    assert(obj.meta_attr.empty?)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_nil(obj.member)
    assert_equal(false, obj.unique)
    assert_equal(false, obj.managed)
    assert_equal(false, obj.failed)
    assert_equal(false, obj.failure_ignored)
    assert_equal(false, obj.promotable)
  end

  def test_init_primitive_with_crm
    obj = ClusterEntity::Clone.new(
      @cib.elements["//clone[@id='dummy-clone']"],
      @crm_mon,
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    assert_equal('dummy-clone', obj.id)
    assert_nil(obj.parent)
    assert_nil(get_clone(obj))
    assert_nil(get_group(obj))
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'dummy-clone-meta_attributes-ccc',
      'ccc',
      '222'
    ) << ClusterEntity::NvPair.new(
      'dummy-clone-meta_attributes-aaa',
      'aaa',
      '222'
    )
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_not_nil(obj.member)
    assert_equal(false, obj.unique)
    assert(obj.managed)
    assert_equal(false, obj.failed)
    assert_equal(false, obj.failure_ignored)
    assert_equal(false, obj.promotable)

    m = obj.member
    assert_instance_of(ClusterEntity::Primitive, m)
    assert_equal(obj, m.parent)
    assert_equal('dummy', m.id)
    assert_equal(3, m.crm_status.length)
    assert_equal(obj.id, get_clone(m))
    assert_nil(get_group(m))
  end

  def test_init_primitive
    obj = ClusterEntity::Clone.new(@cib.elements["//clone[@id='dummy-clone']"])
    assert_equal('dummy-clone', obj.id)
    assert_nil(obj.parent)
    assert_nil(get_clone(obj))
    assert_nil(get_group(obj))
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'dummy-clone-meta_attributes-ccc',
      'ccc',
      '222'
    ) << ClusterEntity::NvPair.new(
      'dummy-clone-meta_attributes-aaa',
      'aaa',
      '222'
    )
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_not_nil(obj.member)
    assert_equal(false, obj.unique)
    assert_equal(false, obj.managed)
    assert_equal(false, obj.failed)
    assert_equal(false, obj.failure_ignored)
    assert_equal(false, obj.promotable)

    m = obj.member
    assert_instance_of(ClusterEntity::Primitive, m)
    assert_equal(obj, m.parent)
    assert_equal('dummy', m.id)
    assert(m.crm_status.empty?)
    assert_equal(obj.id, get_clone(m))
    assert_nil(get_group(m))
  end

  def test_init_group_with_crm
    obj = ClusterEntity::Clone.new(
      @cib.elements["//clone[@id='group2-clone']"],
      @crm_mon,
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'group2-clone-meta_attributes-a',
      'a',
      '1'
    ) << ClusterEntity::NvPair.new(
      'group2-clone-meta_attributes-d',
      'd',
      '1'
    )
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    assert_nil(obj.parent)
    assert_nil(get_clone(obj))
    assert_nil(get_group(obj))
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_not_nil(obj.member)
    assert_equal(false, obj.unique)
    assert(obj.managed)
    assert_equal(false, obj.failed)
    assert_equal(false, obj.failure_ignored)
    assert_equal(false, obj.promotable)

    g = obj.member
    assert_instance_of(ClusterEntity::Group, g)
    assert_equal(obj, g.parent)
    assert_equal('group2', g.id)
    assert_equal(2, g.members.length)
    assert_equal(obj.id, get_clone(g))
    assert_nil(get_group(g))

    m = g.members[0]
    assert_instance_of(ClusterEntity::Primitive, m)
    assert_equal('dummy6', m.id)
    assert_equal(obj.id, get_clone(m))
    assert_equal(g.id, get_group(m))

    m = g.members[1]
    assert_instance_of(ClusterEntity::Primitive, m)
    assert_equal('dummy5', m.id)
    assert_equal(obj.id, get_clone(m))
    assert_equal(g.id, get_group(m))
  end

  def test_init_group
    obj = ClusterEntity::Clone.new(@cib.elements["//clone[@id='group2-clone']"])
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'group2-clone-meta_attributes-a',
      'a',
      '1'
    ) << ClusterEntity::NvPair.new(
      'group2-clone-meta_attributes-d',
      'd',
      '1'
    )
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    assert_nil(obj.parent)
    assert_nil(get_clone(obj))
    assert_nil(get_group(obj))
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_not_nil(obj.member)
    assert_equal(false, obj.unique)
    assert_equal(false, obj.managed)
    assert_equal(false, obj.failed)
    assert_equal(false, obj.failure_ignored)
    assert_equal(false, obj.promotable)

    g = obj.member
    assert_instance_of(ClusterEntity::Group, g)
    assert_equal(obj, g.parent)
    assert_equal('group2', g.id)
    assert_equal(2, g.members.length)
    assert_equal(obj.id, get_clone(g))
    assert_nil(get_group(g))

    m = g.members[0]
    assert_instance_of(ClusterEntity::Primitive, m)
    assert_equal('dummy6', m.id)
    assert_equal(obj.id, get_clone(g))
    assert_equal(g.id, get_group(m))

    m = g.members[1]
    assert_instance_of(ClusterEntity::Primitive, m)
    assert_equal('dummy5', m.id)
    assert_equal(obj.id, get_clone(m))
    assert_equal(g.id, get_group(m))
  end

  def test_to_status_primitive_version1
    obj = ClusterEntity::Clone.new(
      @cib.elements["//clone[@id='dummy-clone']"],
      @crm_mon,
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    assert([] == obj.to_status)
  end

  def test_to_status_group_version1
    obj = ClusterEntity::Clone.new(
      @cib.elements["//clone[@id='group2-clone']"],
      @crm_mon,
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    assert([] == obj.to_status)
  end

  def test_to_status_primitive_version2
    obj = ClusterEntity::Clone.new(
      @cib.elements["//clone[@id='dummy-clone']"],
      @crm_mon,
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    json ='{
      "id": "dummy-clone",
      "meta_attr": [
        {
          "id": "dummy-clone-meta_attributes-aaa",
          "name": "aaa",
          "value": "222"
        },
        {
          "id": "dummy-clone-meta_attributes-ccc",
          "name": "ccc",
          "value": "222"
        }
      ],
      "error_list": [],
      "warning_list": [],
      "class_type": "clone",
      "parent_id": null,
      "disabled": false,
      "status": "running",
      "promotable": false,
      "member": {
        "id": "dummy",
        "meta_attr": [
          {
            "id": "dummy-meta_attributes-aaa",
            "name": "aaa",
            "value": "111"
          },
          {
            "id": "dummy-meta_attributes-bbb",
            "name": "bbb",
            "value": "111"
          }
        ],
        "utilization": [],
        "error_list": [],
        "warning_list": [],
        "class_type": "primitive",
        "parent_id": "dummy-clone",
        "disabled": false,
        "agentname": "ocf::heartbeat:Dummy",
        "provider": "heartbeat",
        "type": "Dummy",
        "stonith": false,
        "instance_attr": [],
        "status": "running",
        "class": "ocf",
        "crm_status": [
          {
            "id": "dummy",
            "resource_agent": "ocf::heartbeat:Dummy",
            "managed": true,
            "failed": false,
            "role": "Started",
            "active": true,
            "orphaned": false,
            "failure_ignored": false,
            "nodes_running_on": 1,
            "pending": null,
            "blocked": false,
            "target_role": null,
            "node": {
              "name": "node3",
              "id": "3",
              "cached": false
            }
          },
          {
            "id": "dummy",
            "resource_agent": "ocf::heartbeat:Dummy",
            "managed": true,
            "failed": false,
            "role": "Started",
            "active": true,
            "orphaned": false,
            "failure_ignored": false,
            "nodes_running_on": 1,
            "pending": null,
            "blocked": false,
            "target_role": null,
            "node": {
              "name": "node1",
              "id": "1",
              "cached": false
            }
          },
          {
            "id": "dummy",
            "resource_agent": "ocf::heartbeat:Dummy",
            "managed": true,
            "failed": false,
            "role": "Started",
            "active": true,
            "orphaned": false,
            "failure_ignored": false,
            "nodes_running_on": 1,
            "pending": null,
            "blocked": false,
            "target_role": null,
            "node": {
              "name": "node2",
              "id": "2",
              "cached": false
            }
          }
        ],
        "operations": []
      }
    }'
    hash = JSON.parse(json, {:symbolize_names => true})
    assert_equal(hash, obj.to_status('2'))
  end

  def test_to_status_group_version2
    obj = ClusterEntity::Clone.new(
      @cib.elements["//clone[@id='group2-clone']"],
      @crm_mon,
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    json = '{
      "id": "group2-clone",
      "meta_attr": [
        {
          "id": "group2-clone-meta_attributes-a",
          "name": "a",
          "value": "1"
        },
        {
          "id": "group2-clone-meta_attributes-d",
          "name": "d",
          "value": "1"
        }
      ],
      "error_list": [],
      "warning_list": [],
      "class_type": "clone",
      "parent_id": null,
      "disabled": false,
      "status": "running",
      "promotable": false,
      "member": {
        "id": "group2",
        "meta_attr": [
          {
            "id": "group2-meta_attributes-a",
            "name": "a",
            "value": "2"
          },
          {
            "id": "group2-meta_attributes-c",
            "name": "c",
            "value": "2"
          },
          {
            "id": "group2-meta_attributes-d",
            "name": "d",
            "value": "2"
          }
        ],
        "error_list": [],
        "warning_list": [],
        "class_type": "group",
        "parent_id": "group2-clone",
        "disabled": false,
        "status": "running",
        "members": [
          {
            "id": "dummy6",
            "meta_attr": [
              {
                "id": "dummy6-meta_attributes-a",
                "name": "a",
                "value": "6"
              },
              {
                "id": "dummy6-meta_attributes-b",
                "name": "b",
                "value": "6"
              }
            ],
            "utilization": [
              {
                "id": "dummy6-utilization-util1",
                "name": "util1",
                "value": "8"
              }
            ],
            "error_list": [],
            "warning_list": [],
            "class_type": "primitive",
            "parent_id": "group2",
            "disabled": false,
            "agentname": "ocf::heartbeat:Dummy",
            "provider": "heartbeat",
            "type": "Dummy",
            "stonith": false,
            "instance_attr": [],
            "status": "running",
            "class": "ocf",
            "crm_status": [
              {
                "id": "dummy6",
                "resource_agent": "ocf::heartbeat:Dummy",
                "managed": true,
                "failed": false,
                "role": "Started",
                "active": true,
                "orphaned": false,
                "failure_ignored": false,
                "nodes_running_on": 1,
                "pending": null,
                "blocked": false,
                "target_role": null,
                "node": {
                  "name": "node3",
                  "id": "3",
                  "cached": false
                }
              },
              {
                "id": "dummy6",
                "resource_agent": "ocf::heartbeat:Dummy",
                "managed": true,
                "failed": false,
                "role": "Started",
                "active": true,
                "orphaned": false,
                "failure_ignored": false,
                "nodes_running_on": 1,
                "pending": null,
                "blocked": false,
                "target_role": null,
                "node": {
                  "name": "node1",
                  "id": "1",
                  "cached": false
                }
              },
              {
                "id": "dummy6",
                "resource_agent": "ocf::heartbeat:Dummy",
                "managed": true,
                "failed": false,
                "role": "Started",
                "active": true,
                "orphaned": false,
                "failure_ignored": false,
                "nodes_running_on": 1,
                "pending": null,
                "blocked": false,
                "target_role": null,
                "node": {
                  "name": "node2",
                  "id": "2",
                  "cached": false
                }
              }
            ],
            "operations": []
          },
          {
            "id": "dummy5",
            "meta_attr": [
              {
                "id": "dummy5-meta_attributes-a",
                "name": "a",
                "value": "5"
              },
              {
                "id": "dummy5-meta_attributes-b",
                "name": "b",
                "value": "5"
              },
              {
                "id": "dummy5-meta_attributes-x",
                "name": "x",
                "value": "0"
              }
            ],
            "utilization": [],
            "error_list": [],
            "warning_list": [],
            "class_type": "primitive",
            "parent_id": "group2",
            "disabled": false,
            "agentname": "ocf::heartbeat:Dummy",
            "provider": "heartbeat",
            "type": "Dummy",
            "stonith": false,
            "instance_attr": [],
            "status": "running",
            "class": "ocf",
            "crm_status": [
              {
                "id": "dummy5",
                "resource_agent": "ocf::heartbeat:Dummy",
                "managed": true,
                "failed": false,
                "role": "Started",
                "active": true,
                "orphaned": false,
                "failure_ignored": false,
                "nodes_running_on": 1,
                "pending": null,
                "blocked": false,
                "target_role": null,
                "node": {
                  "name": "node3",
                  "id": "3",
                  "cached": false
                }
              },
              {
                "id": "dummy5",
                "resource_agent": "ocf::heartbeat:Dummy",
                "managed": true,
                "failed": false,
                "role": "Started",
                "active": true,
                "orphaned": false,
                "failure_ignored": false,
                "nodes_running_on": 1,
                "pending": null,
                "blocked": false,
                "target_role": null,
                "node": {
                  "name": "node1",
                  "id": "1",
                  "cached": false
                }
              },
              {
                "id": "dummy5",
                "resource_agent": "ocf::heartbeat:Dummy",
                "managed": true,
                "failed": false,
                "role": "Started",
                "active": true,
                "orphaned": false,
                "failure_ignored": false,
                "nodes_running_on": 1,
                "pending": null,
                "blocked": false,
                "target_role": null,
                "node": {
                  "name": "node2",
                  "id": "2",
                  "cached": false
                }
              }
            ],
            "operations": []
          }
        ]
      }
    }'
    hash = JSON.parse(json, {:symbolize_names => true})
    assert_equal(hash, obj.to_status('2'))
  end
end

class TestCloneCrmMon1 < Test::Unit::TestCase

  include TestCloneMixin

  def setup
    @cib = REXML::Document.new(File.read(File.join(CURRENT_DIR, CIB_FILE)))
    @crm_mon = REXML::Document.new(File.read(File.join(CURRENT_DIR, 'crm1.xml')))
  end
end

class TestCloneCrmMon2 < Test::Unit::TestCase

  include TestCloneMixin

  def setup
    @cib = REXML::Document.new(File.read(File.join(CURRENT_DIR, CIB_FILE)))
    @crm_mon = REXML::Document.new(File.read(File.join(CURRENT_DIR, 'crm2.xml')))
  end
end


module TestCloneFromPromotableElementMixin
  def test_init_primitive
    obj = ClusterEntity::Clone.new(@cib.elements["//clone[@id='stateful-promotable']"])
    assert_equal('stateful-promotable', obj.id)
    assert_nil(obj.parent)
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'stateful-promotable-meta_attributes-promotable',
      'promotable',
      'true'
    ) << ClusterEntity::NvPair.new(
      'stateful-promotable-meta_attributes-a',
      'a',
      '1'
    ) << ClusterEntity::NvPair.new(
      'stateful-promotable-meta_attributes-b',
      'b',
      '1'
    )
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    assert(obj.error_list.empty?)
    assert_equal(1, obj.warning_list.length)
    assert_not_nil(obj.member)
    assert_equal(false, obj.unique)
    assert_equal(false, obj.managed)
    assert_equal(false, obj.failed)
    assert_equal(false, obj.failure_ignored)
    assert(obj.promotable)

    assert(obj.masters.empty?)
    assert(obj.slaves.empty?)

    m = obj.member
    assert_instance_of(ClusterEntity::Primitive, m)
    assert_equal(obj, m.parent)
    assert_equal('promotable', m.id)
    assert(m.crm_status.empty?)
  end

  def test_to_status_primitive_version1
    obj = ClusterEntity::Clone.new(
      @cib.elements["//clone[@id='stateful-promotable']"],
      @crm_mon,
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    assert_equal([], obj.to_status)
  end

  def test_to_status_primitive_version2
    obj = ClusterEntity::Clone.new(
      @cib.elements["//clone[@id='stateful-promotable']"],
      @crm_mon,
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    json ='{
      "id": "stateful-promotable",
      "meta_attr": [
        {
          "id": "stateful-promotable-meta_attributes-promotable",
          "name": "promotable",
          "value": "true"
        },
        {
          "id": "stateful-promotable-meta_attributes-a",
          "name": "a",
          "value": "1"
        },
        {
          "id": "stateful-promotable-meta_attributes-b",
          "name": "b",
          "value": "1"
        }
      ],
      "error_list": [],
      "warning_list": [
        {
          "message": "Resource is promotable but has not been promoted on any node.",
          "type": "no_master"
        }
      ],
      "class_type": "clone",
      "parent_id": null,
      "disabled": false,
      "status": "blocked",
      "promotable": true,
      "member": {
        "id": "promotable",
        "meta_attr": [
          {
            "id": "promotable-meta_attributes-a",
            "name": "a",
            "value": "0"
          },
          {
            "id": "promotable-meta_attributes-c",
            "name": "c",
            "value": "0"
          }
        ],
        "utilization": [],
        "error_list": [],
        "warning_list": [],
        "class_type": "primitive",
        "parent_id": "stateful-promotable",
        "disabled": false,
        "agentname": "ocf::pacemaker:Stateful",
        "provider": "pacemaker",
        "type": "Stateful",
        "stonith": false,
        "instance_attr": [],
        "status": "blocked",
        "class": "ocf",
        "crm_status": [
        ],
        "operations": []
      }
    }'
    hash = JSON.parse(json, {:symbolize_names => true})
    assert_equal(hash, obj.to_status('2'))
  end
end

class TestCloneFromPromotableElementCrmMon1 < Test::Unit::TestCase

  include TestCloneFromPromotableElementMixin

  def setup
    @cib = REXML::Document.new(File.read(File.join(CURRENT_DIR, CIB_FILE)))
    @crm_mon = REXML::Document.new(File.read(File.join(CURRENT_DIR, 'crm1.xml')))
  end
end

class TestCloneFromPromotableElementCrmMon2 < Test::Unit::TestCase

  include TestCloneFromPromotableElementMixin

  def setup
    @cib = REXML::Document.new(File.read(File.join(CURRENT_DIR, CIB_FILE)))
    @crm_mon = REXML::Document.new(File.read(File.join(CURRENT_DIR, 'crm2.xml')))
  end
end


module TestCloneFromMasterElementMixin
  def test_init_primitive_with_crm
    obj = ClusterEntity::Clone.new(
      @cib.elements["//master[@id='ms-master']"],
      @crm_mon,
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    assert_equal('ms-master', obj.id)
    assert_nil(obj.parent)
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'ms-master-meta_attributes-a',
      'a',
      '1'
    ) << ClusterEntity::NvPair.new(
      'ms-master-meta_attributes-b',
      'b',
      '1'
    )
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_not_nil(obj.member)
    assert_equal(false, obj.unique)
    assert(obj.managed)
    assert_equal(false, obj.failed)
    assert_equal(false, obj.failure_ignored)
    assert(obj.promotable)

    assert_equal(1, obj.masters.length)
    assert_equal('node3', obj.masters[0])

    assert_equal(2, obj.slaves.length)
    assert(obj.slaves.include?('node1'))
    assert(obj.slaves.include?('node2'))

    m = obj.member
    assert_instance_of(ClusterEntity::Primitive, m)
    assert_equal(obj, m.parent)
    assert_equal('ms', m.id)
    assert_equal(3, m.crm_status.length)
  end

  def test_init_primitive
    obj = ClusterEntity::Clone.new(@cib.elements["//master[@id='ms-master']"])
    assert_equal('ms-master', obj.id)
    assert_nil(obj.parent)
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'ms-master-meta_attributes-a',
      'a',
      '1'
    ) << ClusterEntity::NvPair.new(
      'ms-master-meta_attributes-b',
      'b',
      '1'
    )
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    assert(obj.error_list.empty?)
    assert_equal(1, obj.warning_list.length)
    assert_not_nil(obj.member)
    assert_equal(false, obj.unique)
    assert_equal(false, obj.managed)
    assert_equal(false, obj.failed)
    assert_equal(false, obj.failure_ignored)
    assert(obj.promotable)

    assert(obj.masters.empty?)
    assert(obj.slaves.empty?)

    m = obj.member
    assert_instance_of(ClusterEntity::Primitive, m)
    assert_equal(obj, m.parent)
    assert_equal('ms', m.id)
    assert(m.crm_status.empty?)
  end

  def test_init_group_with_crm
    obj = ClusterEntity::Clone.new(
      @cib.elements["//master[@id='group3-master']"],
      @crm_mon,
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    assert_equal('group3-master', obj.id)
    assert_nil(obj.parent)
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'group3-master-meta_attributes-a',
      'a',
      '0'
    ) << ClusterEntity::NvPair.new(
      'group3-master-meta_attributes-c',
      'c',
      '0'
    )
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    assert(obj.error_list.empty?)
    assert(obj.warning_list.empty?)
    assert_not_nil(obj.member)
    assert_equal(false, obj.unique)
    assert(obj.managed)
    assert_equal(false, obj.failed)
    assert_equal(false, obj.failure_ignored)
    assert(obj.promotable)

    assert_equal(2, obj.masters.length)
    assert_equal('node3', obj.masters[0])
    assert_equal('node3', obj.masters[1])

    assert_equal(4, obj.slaves.length)
    assert(['node1', 'node2'].to_set == obj.slaves.to_set)

    g = obj.member
    assert_instance_of(ClusterEntity::Group, g)
    assert_equal(obj, g.parent)
    assert_equal('group3', g.id)
    assert_equal(2, g.members.length)

    m = g.members[0]
    assert_instance_of(ClusterEntity::Primitive, m)
    assert_equal('ms1', m.id)
    assert_equal(3, m.crm_status.length)

    m = g.members[1]
    assert_instance_of(ClusterEntity::Primitive, m)
    assert_equal('ms2', m.id)
    assert_equal(3, m.crm_status.length)
  end

  def test_init_group
    obj = ClusterEntity::Clone.new(@cib.elements["//master[@id='group3-master']"])
    assert_equal('group3-master', obj.id)
    assert_nil(obj.parent)
    meta_attr = ClusterEntity::NvSet.new << ClusterEntity::NvPair.new(
      'group3-master-meta_attributes-a',
      'a',
      '0'
    ) << ClusterEntity::NvPair.new(
      'group3-master-meta_attributes-c',
      'c',
      '0'
    )
    assert_equal_NvSet(meta_attr, obj.meta_attr)
    assert(obj.error_list.empty?)
    assert_equal(1, obj.warning_list.length)
    assert_not_nil(obj.member)
    assert_equal(false, obj.unique)
    assert_equal(false, obj.managed)
    assert_equal(false, obj.failed)
    assert_equal(false, obj.failure_ignored)
    assert(obj.promotable)

    assert(obj.masters.empty?)
    assert(obj.slaves.empty?)

    g = obj.member
    assert_instance_of(ClusterEntity::Group, g)
    assert_equal(obj, g.parent)
    assert_equal('group3', g.id)
    assert_equal(2, g.members.length)

    m = g.members[0]
    assert_instance_of(ClusterEntity::Primitive, m)
    assert_equal('ms1', m.id)
    assert(m.crm_status.empty?)

    m = g.members[1]
    assert_instance_of(ClusterEntity::Primitive, m)
    assert_equal('ms2', m.id)
    assert(m.crm_status.empty?)
  end

  def test_to_status_primitive_version1
    obj = ClusterEntity::Clone.new(
      @cib.elements["//master[@id='ms-master']"],
      @crm_mon,
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    assert_equal([], obj.to_status)
  end

  def test_to_status_group_version1
    obj = ClusterEntity::Clone.new(
      @cib.elements["//master[@id='group3-master']"],
      @crm_mon,
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    assert([] == obj.to_status)
  end

  def test_to_status_primitive_version2
    obj = ClusterEntity::Clone.new(
      @cib.elements["//master[@id='ms-master']"],
      @crm_mon,
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    json ='{
      "id": "ms-master",
      "meta_attr": [
        {
          "id": "ms-master-meta_attributes-a",
          "name": "a",
          "value": "1"
        },
        {
          "id": "ms-master-meta_attributes-b",
          "name": "b",
          "value": "1"
        }
      ],
      "error_list": [],
      "warning_list": [],
      "class_type": "clone",
      "parent_id": null,
      "disabled": false,
      "status": "running",
      "promotable": true,
      "member": {
        "id": "ms",
        "meta_attr": [
          {
            "id": "ms-meta_attributes-a",
            "name": "a",
            "value": "0"
          },
          {
            "id": "ms-meta_attributes-c",
            "name": "c",
            "value": "0"
          }
        ],
        "utilization": [],
        "error_list": [],
        "warning_list": [],
        "class_type": "primitive",
        "parent_id": "ms-master",
        "disabled": false,
        "agentname": "ocf::pacemaker:Stateful",
        "provider": "pacemaker",
        "type": "Stateful",
        "stonith": false,
        "instance_attr": [],
        "status": "running",
        "class": "ocf",
        "crm_status": [
          {
            "id": "ms",
            "resource_agent": "ocf::pacemaker:Stateful",
            "managed": true,
            "failed": false,
            "role": "Master",
            "active": true,
            "orphaned": false,
            "failure_ignored": false,
            "nodes_running_on": 1,
            "pending": null,
            "blocked": false,
            "target_role": null,
            "node": {
              "name": "node3",
              "id": "3",
              "cached": false
            }
          },
          {
            "id": "ms",
            "resource_agent": "ocf::pacemaker:Stateful",
            "managed": true,
            "failed": false,
            "role": "Slave",
            "active": true,
            "orphaned": false,
            "failure_ignored": false,
            "nodes_running_on": 1,
            "pending": null,
            "blocked": false,
            "target_role": null,
            "node": {
              "name": "node1",
              "id": "1",
              "cached": false
            }
          },
          {
            "id": "ms",
            "resource_agent": "ocf::pacemaker:Stateful",
            "managed": true,
            "failed": false,
            "role": "Slave",
            "active": true,
            "orphaned": false,
            "failure_ignored": false,
            "nodes_running_on": 1,
            "pending": null,
            "blocked": false,
            "target_role": null,
            "node": {
              "name": "node2",
              "id": "2",
              "cached": false
            }
          }
        ],
        "operations": []
      }
    }'
    hash = JSON.parse(json, {:symbolize_names => true})
    assert_equal(hash, obj.to_status('2'))
  end

  def test_to_status_group_version2
    obj = ClusterEntity::Clone.new(
      @cib.elements["//master[@id='group3-master']"],
      @crm_mon,
      ClusterEntity::get_rsc_status(@crm_mon)
    )
    json = '{
      "id": "group3-master",
      "meta_attr": [
        {
          "id": "group3-master-meta_attributes-a",
          "name": "a",
          "value": "0"
        },
        {
          "id": "group3-master-meta_attributes-c",
          "name": "c",
          "value": "0"
        }
      ],
      "error_list": [],
      "warning_list": [],
      "class_type": "clone",
      "parent_id": null,
      "disabled": false,
      "status": "running",
      "promotable": true,
      "member": {
        "id": "group3",
        "meta_attr": [
          {
            "id": "group3-meta_attributes-a",
            "name": "a",
            "value": "3"
          },
          {
            "id": "group3-meta_attributes-b",
            "name": "b",
            "value": "3"
          },
          {
            "id": "group3-meta_attributes-c",
            "name": "c",
            "value": "3"
          }
        ],
        "error_list": [],
        "warning_list": [],
        "class_type": "group",
        "parent_id": "group3-master",
        "disabled": false,
        "status": "running",
        "members": [
          {
            "id": "ms1",
            "meta_attr": [
              {
                "id": "ms1-meta_attributes-a",
                "name": "a",
                "value": "1"
              },
              {
                "id": "ms1-meta_attributes-b",
                "name": "b",
                "value": "1"
              },
              {
                "id": "ms1-meta_attributes-d",
                "name": "d",
                "value": "1"
              }
            ],
            "utilization": [],
            "error_list": [],
            "warning_list": [],
            "class_type": "primitive",
            "parent_id": "group3",
            "disabled": false,
            "agentname": "ocf::pacemaker:Stateful",
            "provider": "pacemaker",
            "type": "Stateful",
            "stonith": false,
            "instance_attr": [],
            "status": "running",
            "class": "ocf",
            "crm_status": [
              {
                "id": "ms1",
                "resource_agent": "ocf::pacemaker:Stateful",
                "managed": true,
                "failed": false,
                "role": "Master",
                "active": true,
                "orphaned": false,
                "failure_ignored": false,
                "nodes_running_on": 1,
                "pending": null,
                "blocked": false,
                "target_role": null,
                "node": {
                  "name": "node3",
                  "id": "3",
                  "cached": false
                }
              },
              {
                "id": "ms1",
                "resource_agent": "ocf::pacemaker:Stateful",
                "managed": true,
                "failed": false,
                "role": "Slave",
                "active": true,
                "orphaned": false,
                "failure_ignored": false,
                "nodes_running_on": 1,
                "pending": null,
                "blocked": false,
                "target_role": null,
                "node": {
                  "name": "node1",
                  "id": "1",
                  "cached": false
                }
              },
              {
                "id": "ms1",
                "resource_agent": "ocf::pacemaker:Stateful",
                "managed": true,
                "failed": false,
                "role": "Slave",
                "active": true,
                "orphaned": false,
                "failure_ignored": false,
                "nodes_running_on": 1,
                "pending": null,
                "blocked": false,
                "target_role": null,
                "node": {
                  "name": "node2",
                  "id": "2",
                  "cached": false
                }
              }
            ],
            "operations": []
          },
          {
            "id": "ms2",
            "meta_attr": [
              {
                "id": "ms2-meta_attributes-a",
                "name": "a",
                "value": "2"
              },
              {
                "id": "ms2-meta_attributes-b",
                "name": "b",
                "value": "2"
              },
              {
                "id": "ms2-meta_attributes-d",
                "name": "d",
                "value": "2"
              }
            ],
            "utilization": [],
            "error_list": [],
            "warning_list": [],
            "class_type": "primitive",
            "parent_id": "group3",
            "disabled": false,
            "agentname": "ocf::pacemaker:Stateful",
            "provider": "pacemaker",
            "type": "Stateful",
            "stonith": false,
            "instance_attr": [],
            "status": "running",
            "class": "ocf",
            "crm_status": [
              {
                "id": "ms2",
                "resource_agent": "ocf::pacemaker:Stateful",
                "managed": true,
                "failed": false,
                "role": "Master",
                "active": true,
                "orphaned": false,
                "failure_ignored": false,
                "nodes_running_on": 1,
                "pending": null,
                "blocked": false,
                "target_role": null,
                "node": {
                  "name": "node3",
                  "id": "3",
                  "cached": false
                }
              },
              {
                "id": "ms2",
                "resource_agent": "ocf::pacemaker:Stateful",
                "managed": true,
                "failed": false,
                "role": "Slave",
                "active": true,
                "orphaned": false,
                "failure_ignored": false,
                "nodes_running_on": 1,
                "pending": null,
                "blocked": false,
                "target_role": null,
                "node": {
                  "name": "node1",
                  "id": "1",
                  "cached": false
                }
              },
              {
                "id": "ms2",
                "resource_agent": "ocf::pacemaker:Stateful",
                "managed": true,
                "failed": false,
                "role": "Slave",
                "active": true,
                "orphaned": false,
                "failure_ignored": false,
                "nodes_running_on": 1,
                "pending": null,
                "blocked": false,
                "target_role": null,
                "node": {
                  "name": "node2",
                  "id": "2",
                  "cached": false
                }
              }
            ],
            "operations": []
          }
        ]
      }
    }'
    hash = JSON.parse(json, {:symbolize_names => true})
    assert_equal(hash, obj.to_status('2'))
  end
end

class TestCloneFromMasterElementCrmMon1 < Test::Unit::TestCase

  include TestCloneFromMasterElementMixin

  def setup
    @cib = REXML::Document.new(File.read(File.join(CURRENT_DIR, CIB_FILE)))
    @crm_mon = REXML::Document.new(File.read(File.join(CURRENT_DIR, 'crm1.xml')))
  end
end

class TestCloneFromMasterElementCrmMon2 < Test::Unit::TestCase

  include TestCloneFromMasterElementMixin

  def setup
    @cib = REXML::Document.new(File.read(File.join(CURRENT_DIR, CIB_FILE)))
    @crm_mon = REXML::Document.new(File.read(File.join(CURRENT_DIR, 'crm2.xml')))
  end
end
