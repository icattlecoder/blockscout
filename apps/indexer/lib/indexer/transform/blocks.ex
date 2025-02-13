defmodule Indexer.Transform.Blocks do
  @moduledoc """
  Protocol for transforming blocks.
  """

  @type block :: map()

  @doc """
  Transforms a block.
  """
  @callback transform(block :: block()) :: block()

  @doc """
  Runs a list of blocks through the configured block transformer.
  """
  def transform_blocks(blocks) when is_list(blocks) do
    transformer = Application.get_env(:indexer, :block_transformer)

    Enum.map(blocks, &transformer.transform/1)
  end

  @doc """
  Calculates the signer's address by recovering the ECDSA public key.

  https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm
  """
  def signer(block) when is_map(block) do
    # Last 65 bytes is the signature. Multiply by two since we haven't transformed to raw bytes
    {extra_data, signature} = String.split_at(trim_prefix(block.extra_data), -130)

    block = %{block | extra_data: extra_data}

    signature_hash = signature_hash(block)

    recover_pub_key(signature_hash, decode(signature))
  end

  def istanbl_signer(block) when is_map(block) do

    {filtered_extra_data, seal} = istanbl_extra_data(block)

    signature_hash = istanbl_signature_hash(block, filtered_extra_data)

    ## need double hash
    hash_signature_hash = :keccakf1600.hash(:sha3_256, signature_hash)

    recover_pub_key(hash_signature_hash, seal)
  end

  defp istanbl_extra_data(block) do

    <<origin_extra::bytes-size(32), istanbl_extra_data::binary>> = decode(block.extra_data)

    [ validators, seal, _ ] = ExRLP.decode(istanbl_extra_data)

    encoded_filtered_intanbl_extra_data = ExRLP.encode([validators, <<>>, []])

    filtered_extra_data = origin_extra <> encoded_filtered_intanbl_extra_data

    { filtered_extra_data, seal}
  end

  defp istanbl_signature_hash(block,extra_data) do
    header_data = [
      decode(block.parent_hash),
      decode(block.sha3_uncles),
      decode(block.miner_hash),
      decode(block.state_root),
      decode(block.transactions_root),
      decode(block.receipts_root),
      decode(block.logs_bloom),
      block.difficulty,
      block.number,
      block.gas_limit,
      block.gas_used,
      DateTime.to_unix(block.timestamp),
      extra_data,
      decode(block.mix_hash),
      decode(block.nonce)
    ]

    :keccakf1600.hash(:sha3_256, ExRLP.encode(header_data))
  end

  # Signature hash calculated from the block header.
  # Needed for PoA-based chains
  defp signature_hash(block) do
    header_data = [
      decode(block.parent_hash),
      decode(block.sha3_uncles),
      decode(block.miner_hash),
      decode(block.state_root),
      decode(block.transactions_root),
      decode(block.receipts_root),
      decode(block.logs_bloom),
      block.difficulty,
      block.number,
      block.gas_limit,
      block.gas_used,
      DateTime.to_unix(block.timestamp),
      decode(block.extra_data),
      decode(block.mix_hash),
      decode(block.nonce)
    ]

    :keccakf1600.hash(:sha3_256, ExRLP.encode(header_data))
  end

  defp trim_prefix("0x" <> rest), do: rest

  defp decode("0x" <> rest) do
    decode(rest)
  end

  defp decode(data) do
    Base.decode16!(data, case: :mixed)
  end

  # Recovers the key from the signature hash and signature
  defp recover_pub_key(signature_hash, signature) do
    <<
      r::bytes-size(32),
      s::bytes-size(32),
      v::integer-size(8)
    >> = signature

    # First byte represents compression which can be ignored
    # Private key is the last 64 bytes
    {:ok, <<_compression::bytes-size(1), private_key::binary>>} =
      :libsecp256k1.ecdsa_recover_compact(signature_hash, r <> s, :uncompressed, v)

    # Public key comes from the last 20 bytes
    <<_::bytes-size(12), public_key::binary>> = :keccakf1600.hash(:sha3_256, private_key)

    miner_address = Base.encode16(public_key, case: :lower)
    "0x" <> miner_address
  end
end
