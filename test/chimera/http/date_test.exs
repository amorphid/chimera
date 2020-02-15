defmodule Chimera.HTTP.DateTest do
  use ExUnit.Case, async: true

  alias Chimera.HTTP.Date

  describe "&utc_formatted_string_now/{0,1}" do
    test "zero pads day, year, hour, mintute, and second" do
      actual = Date.utc_formatted_string_now(~U[0001-01-01 01:01:01.771526Z])
      expected = "Mon, 01 Jan 0001 01:01:01 GMT"
      assert actual == expected
    end

    test "sets 2020-04-06 to Monday" do
      actual = Date.utc_formatted_string_now(~U[2020-04-06 21:05:17.771526Z])
      expected = "Mon, 06 Apr 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-04-07 to Tuesday" do
      actual = Date.utc_formatted_string_now(~U[2020-04-07 21:05:17.771526Z])
      expected = "Tue, 07 Apr 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-04-08 to Wednesday" do
      actual = Date.utc_formatted_string_now(~U[2020-04-08 21:05:17.771526Z])
      expected = "Wed, 08 Apr 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-04-09 to Thursday" do
      actual = Date.utc_formatted_string_now(~U[2020-04-09 21:05:17.771526Z])
      expected = "Thu, 09 Apr 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-04-10 to Friday" do
      actual = Date.utc_formatted_string_now(~U[2020-04-10 21:05:17.771526Z])
      expected = "Fri, 10 Apr 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-04-11 to Saturday" do
      actual = Date.utc_formatted_string_now(~U[2020-04-11 21:05:17.771526Z])
      expected = "Sat, 11 Apr 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-04-12 to Sunday" do
      actual = Date.utc_formatted_string_now(~U[2020-04-12 21:05:17.771526Z])
      expected = "Sun, 12 Apr 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-01-01 to January" do
      actual = Date.utc_formatted_string_now(~U[2020-01-01 21:05:17.771526Z])
      expected = "Wed, 01 Jan 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-02-01 to February" do
      actual = Date.utc_formatted_string_now(~U[2020-02-01 21:05:17.771526Z])
      expected = "Sat, 01 Feb 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-03-01 to March" do
      actual = Date.utc_formatted_string_now(~U[2020-03-01 21:05:17.771526Z])
      expected = "Sun, 01 Mar 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-04-01 to April" do
      actual = Date.utc_formatted_string_now(~U[2020-04-01 21:05:17.771526Z])
      expected = "Wed, 01 Apr 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-05-01 to May" do
      actual = Date.utc_formatted_string_now(~U[2020-05-01 21:05:17.771526Z])
      expected = "Fri, 01 May 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-06-01 to June" do
      actual = Date.utc_formatted_string_now(~U[2020-06-01 21:05:17.771526Z])
      expected = "Mon, 01 Jun 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-07-01 to July" do
      actual = Date.utc_formatted_string_now(~U[2020-07-01 21:05:17.771526Z])
      expected = "Wed, 01 Jul 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-08-01 to August" do
      actual = Date.utc_formatted_string_now(~U[2020-08-01 21:05:17.771526Z])
      expected = "Sat, 01 Aug 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-09-01 to September" do
      actual = Date.utc_formatted_string_now(~U[2020-09-01 21:05:17.771526Z])
      expected = "Tue, 01 Sep 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-10-01 to October" do
      actual = Date.utc_formatted_string_now(~U[2020-10-01 21:05:17.771526Z])
      expected = "Thu, 01 Oct 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-11-01 to November" do
      actual = Date.utc_formatted_string_now(~U[2020-11-01 21:05:17.771526Z])
      expected = "Sun, 01 Nov 2020 21:05:17 GMT"
      assert actual == expected
    end

    test "sets 2020-12-01 to December" do
      actual = Date.utc_formatted_string_now(~U[2020-12-01 21:05:17.771526Z])
      expected = "Tue, 01 Dec 2020 21:05:17 GMT"
      assert actual == expected
    end
  end
end
