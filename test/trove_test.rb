require_relative "test_helper"

class TroveTest < Minitest::Test
  def setup
    Dir.chdir(Dir.mktmpdir)
    Dir.mkdir("trove")
    File.write ".trove.yml", <<~EOS
      storage: s3://#{ENV.fetch("S3_BUCKET")}/trove
    EOS
    [:config, :root, :storage].each do |var|
      Trove.instance_variable_set("@#{var}", nil)
    end
  end

  def test_works
    Trove.delete("test.txt")

    File.write("trove/test.txt", "hello")

    Trove.push("test.txt")
    Trove.push("test.txt")

    Trove.pull("test.txt")
    Trove.pull("test.txt")

    File.unlink("trove/test.txt")

    Trove.pull("test.txt")

    File.write("trove/test.txt", "hello!")

    Trove.pull("test.txt")

    assert_equal "hello", File.read("trove/test.txt")
  end

  def test_pull_not_found
    error = assert_raises do
      Trove.pull("missing.txt")
    end
    assert_equal "File not found", error.message
  end

  def test_push_not_found
    error = assert_raises do
      Trove.push("missing.txt")
    end
    assert_equal "File not found", error.message
  end

  def test_delete
    Trove.delete("test.txt")
  end

  def test_delete_version
    # TODO
  end

  def test_list
    Trove.list
  end

  def test_versions
    Trove.versions("test.txt")
  end

  def test_config_not_found
    File.unlink(".trove.yml")
    error = assert_raises do
      Trove.pull("test.txt")
    end
    assert_equal "Config not found", error.message
  end

  def test_invalid_storage_provider
    File.write ".trove.yml", <<~EOS
      storage: bad://test/trove
    EOS
    error = assert_raises do
      Trove.pull("test.txt")
    end
    assert_equal "Invalid storage provider: bad", error.message
  end
end
