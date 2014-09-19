defmodule KV.Registry do
  use GenServer
  ##客户端API

  @doc """
  启动注册表进程
  """
  def start_link(event_manager, buckets, opts \\ []) do
    #1.已参数传递桶监控者
    GenServer.start_link(__MODULE__, {event_manager, buckets}, opts)
  end

  @doc """
  根据名称查找存储在`服务器`端的“桶”的进程号(pid)
  如果“桶”存在，返回 `{:ok,pid}`，否则返回`:error`。
  """
  def lookup(server,name) do
    GenServer.call(server, {:lookup, name})
  end

  @doc """
  保证服务器端`server`存在一个指定名称`name`相关联的“桶”
  """
  def create(server, name) do
    GenServer.cast(server, {:create, name})
  end

  @doc """
  停止注册表进程
  """
  def stop(server) do
    GenServer.call(server, :stop)
  end

  ##服务器端回调
  def init({events,buckets}) do
    names = HashDict.new
    refs  = HashDict.new
    #2. 状态中存入桶监控器
    {:ok, %{names: names, refs: refs, events: events, buckets: buckets}}
  end

  def handle_call({:lookup, name}, _from, state) do
    {:reply, HashDict.fetch(state.names, name), state}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_cast({:create, name}, state) do
    if HashDict.get(state.names, name) do
      {:noreply, state}
    else
      #3.用桶进程代替直接启动“桶”
      {:ok, pid} = KV.Bucket.Supervisor.start_bucket(state.buckets)
      ref = Process.monitor(pid)
      refs = HashDict.put(state.refs, ref, name)
      names = HashDict.put(state.names, name, pid)
      GenEvent.sync_notify(state.events, {:create, name, pid})
      {:noreply, %{state| names: names, refs: refs}}
    end
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    {name, refs} = HashDict.pop(state.refs, ref)
    names = HashDict.delete(state.names, name)
    GenEvent.sync_notify(state.events, {:exit, name, pid})
    {:noreply, %{state| names: names, refs: refs}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end