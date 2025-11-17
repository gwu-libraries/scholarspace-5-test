RSpec.configure do |config|

  config.before(:suite) do
    conn = Hyrax.index_adapter.connection
    conn.delete_by_query('*:*', params: { 'softCommit' => true })
    Hyrax.persister.wipe!
  end

  config.before(:each) do
    conn = Hyrax.index_adapter.connection
    conn.delete_by_query('*:*', params: { 'softCommit' => true })
    Hyrax.persister.wipe!!
  end

  config.after(:each) do
    conn = Hyrax.index_adapter.connection
    conn.delete_by_query('*:*', params: { 'softCommit' => true })
    Hyrax.persister.wipe!
  end

end