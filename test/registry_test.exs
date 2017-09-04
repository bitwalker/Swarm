defmodule Swarm.RegistryTests do
  use ExUnit.Case, async: false

  import Swarm.Entry
  @moduletag :capture_log

  setup_all do
    :rand.seed(:exs64)
    Application.ensure_all_started(:swarm)
    {:ok, _} = MyApp.WorkerSup.start_link()
    :ok
  end

  test "register_name/4" do
    {:ok, pid1} = Swarm.register_name({:test, 1}, MyApp.WorkerSup, :register, [])
    {:ok, pid2} = Swarm.register_name({:test, 2}, MyApp.WorkerSup, :register, [])

    Process.sleep(1_000)

    assert ^pid1 = Swarm.Registry.whereis({:test, 1})
    assert ^pid2 = Swarm.Registry.whereis({:test, 2})

    all = Swarm.Registry.all()
    assert Enum.member?(all, {{:test, 1}, pid1})
    assert Enum.member?(all, {{:test, 2}, pid2})

    assert entry(name: _, pid: ^pid1, ref: ref1, meta: _, clock: _) = Swarm.Registry.get_by_name({:test, 1})
    assert entry(name: _, pid: ^pid2, ref: ref2, meta: _, clock: _) = Swarm.Registry.get_by_name({:test, 2})

    assert [entry(name: {:test, 1}, pid: _, ref: _, meta: _, clock: _)] = Swarm.Registry.get_by_pid(pid1)
    assert [entry(name: {:test, 2}, pid: _, ref: _, meta: _, clock: _)] = Swarm.Registry.get_by_pid(pid2)

    assert entry(name: _, pid: _, ref: ^ref1, meta: _, clock: _) = Swarm.Registry.get_by_pid_and_name(pid1, {:test, 1})
    assert entry(name: _, pid: _, ref: ^ref2, meta: _, clock: _) = Swarm.Registry.get_by_pid_and_name(pid2, {:test, 2})

    assert entry(name: _, pid: ^pid1, ref: _, meta: _, clock: _) = Swarm.Registry.get_by_ref(ref1)
    assert entry(name: _, pid: ^pid2, ref: _, meta: _, clock: _) = Swarm.Registry.get_by_ref(ref2)

    assert [entry(pid: ^pid2), entry(pid: ^pid1)] = Swarm.Registry.get_by_meta(:mfa, {MyApp.WorkerSup, :register, []})

    assert [entry(pid: ^pid1)] = :ets.lookup(:swarm_registry, {:test, 1})
  end

  test "join/2 (joining a group does not create race conditions)" do
    # https://github.com/bitwalker/swarm/issues/14
    {:ok, pid} = Agent.start_link(fn -> "testing" end)
    Swarm.register_name(:agent, pid)
    Swarm.join(:agents, pid)
    assert [my_agent] = Swarm.members(:agents)
    assert "testing" == Agent.get(my_agent, fn s -> s end)
  end
end
