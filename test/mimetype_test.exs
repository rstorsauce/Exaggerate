defmodule ExaggerateTest.MimetypeTest do
  use ExUnit.Case

  describe "mimetypes" do
    test "" do
      assert {:error, :mimetype} ==
        Exaggerate.Tools.match_mimetype({"text","html"},
          ["application/json", "image/jpeg"], nil)

      assert {:error, :mimetype} ==
        Exaggerate.Tools.match_mimetype({"application","x-vnd-zip"},
          ["application/json", "image/jpeg"], nil)

      assert {:ok, "application/json"} ==
        Exaggerate.Tools.match_mimetype({"application","json"},
          ["application/json", "image/jpeg"], nil)

      assert {:ok, "image/jpeg"} ==
        Exaggerate.Tools.match_mimetype({"image","jpeg"},
          ["application/json", "image/jpeg"], nil)

      assert {:ok, "image/jpeg"} ==
        Exaggerate.Tools.match_mimetype({"image","jpeg"},
          ["image/*", "application/json", "image/jpeg"], nil)

      assert {:ok, "image/jpeg"} ==
        Exaggerate.Tools.match_mimetype({"image","jpeg"},
          ["*/*", "application/json", "image/jpeg"], nil)

      assert {:ok, "image/*"} ==
        Exaggerate.Tools.match_mimetype({"image","jpeg"},
          ["application/json", "image/*"], nil)

      assert {:ok, "image/*"} ==
        Exaggerate.Tools.match_mimetype({"image","jpeg"},
          ["image/*", "application/json"], nil)

      assert {:ok, "image/*"} ==
        Exaggerate.Tools.match_mimetype({"image","jpeg"},
          ["image/*", "application/json", "*/*"], nil)

      assert {:ok, "image/*"} ==
        Exaggerate.Tools.match_mimetype({"image","jpeg"},
          ["*/*", "image/*", "application/json"], nil)

      assert {:ok, "*/*"} ==
        Exaggerate.Tools.match_mimetype({"image","jpeg"},
          ["*/*", "application/json"], nil)
    end
  end
end
