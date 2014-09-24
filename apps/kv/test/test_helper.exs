exclude =
  if Node.alive?, do: [], else: [distributed: true]
ExUnit.start()
