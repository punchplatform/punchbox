{
  type: punchline
  version: "6.0"
  tenant: default
  channel: default
  runtime: spark
  dag:
  [
    {
      settings:
      {
        input_data:
        [
          {
            name: phil
            musician: false
            age: 21
            friends:
            [
              alice
            ]
          }
          {
            name: alice
            musician: true
            age: 23
            friends:
            [
              dimi
            ]
          }
          {
            name: dimi
            musician: true
            age: 53
            friends:
            [
              phil
              alice
            ]
          }
        ]
      }
      component: input
      publish:
      [
        {
          stream: data
        }
      ]
      description:
        '''
        The batch_input node simply generates some data.
        You simply write your data inline, it convert it as Dataset<Row>
        '''
      type: dataset_generator
    }
    {
      settings:
      {
        truncate: false
      }
      component: show
      subscribe:
      [
        {
          component: input
          stream: data
        }
      ]
      type: show
    }
  ]
}
