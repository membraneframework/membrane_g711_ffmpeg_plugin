#include "decoder.h"

void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);

  if (state->codec_ctx != NULL) {
    avcodec_free_context(&state->codec_ctx);
  }
}

UNIFEX_TERM create(UnifexEnv *env) {
  UNIFEX_TERM res;
  State *state = unifex_alloc_state(env);
  state->codec_ctx = NULL;

  av_log_set_level(AV_LOG_QUIET);

#if (LIBAVCODEC_VERSION_MAJOR < 58)
  avcodec_register_all();
#endif
  const AVCodec *codec = avcodec_find_decoder(AV_CODEC_ID_PCM_ALAW);
  if (!codec) {
    res = create_result_error(env, "nocodec");
    goto exit_create;
  }

  state->codec_ctx = avcodec_alloc_context3(codec);
  if (!state->codec_ctx) {
    res = create_result_error(env, "codec_alloc");
    goto exit_create;
  }

  state->codec_ctx->sample_rate = G711_SAMPLE_RATE;
  state->codec_ctx->ch_layout.nb_channels = G711_NUM_CHANNELS;

  if (avcodec_open2(state->codec_ctx, codec, NULL) < 0) {
    res = create_result_error(env, "codec_open");
    goto exit_create;
  }

  res = create_result_ok(env, state);
exit_create:
  unifex_release_state(env, state);
  return res;
}

static int get_frames(UnifexEnv *env, AVPacket *pkt,
                      UnifexPayload ***ret_frames, int *max_frames,
                      int *frame_cnt, State *state) {
  AVFrame *frame = av_frame_alloc();
  UnifexPayload **frames = unifex_alloc((*max_frames) * sizeof(*frames));

  int ret = avcodec_send_packet(state->codec_ctx, pkt);
  if (ret < 0) {
    ret = DECODER_SEND_PKT_ERROR;
    goto exit_get_frames;
  }

  ret = avcodec_receive_frame(state->codec_ctx, frame);
  while (ret != AVERROR(EAGAIN) && ret != AVERROR_EOF) {
    if (ret < 0) {
      ret = DECODER_DECODE_ERROR;
      goto exit_get_frames;
    }

    if (*frame_cnt >= (*max_frames)) {
      *max_frames *= 2;
      frames = unifex_realloc(frames, (*max_frames) * sizeof(*frames));
    }

    size_t payload_size = (size_t)frame->linesize[0];

    frames[*frame_cnt] = unifex_alloc(sizeof(UnifexPayload));

    /* TODO: add shm support? */
    unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, payload_size, frames[*frame_cnt]);
    memcpy(frames[*frame_cnt]->data, (const uint8_t *)frame->data[0], payload_size);
    (*frame_cnt)++;

    ret = avcodec_receive_frame(state->codec_ctx, frame);
  }
  ret = 0;
exit_get_frames:
  *ret_frames = frames;
  av_frame_free(&frame);
  return ret;
}

UNIFEX_TERM decode(UnifexEnv *env, UnifexPayload *payload, State *state) {
  UNIFEX_TERM res_term;
  int res = 0;
  int max_frames = 16, frame_cnt = 0;
  UnifexPayload **out_frames = NULL;

  AVPacket *pkt = av_packet_alloc();
  pkt->data = payload->data;
  pkt->size = payload->size;

  if (pkt->size > 0) {
    res = get_frames(env, pkt, &out_frames, &max_frames, &frame_cnt, state);
  }

  switch (res) {
  case DECODER_SEND_PKT_ERROR:
    res_term = decode_result_error(env, "send_pkt");
    break;
  case DECODER_DECODE_ERROR:
    res_term = decode_result_error(env, "decode");
    break;
  default:
    res_term = decode_result_ok(env, out_frames, frame_cnt);
  }

  if (out_frames != NULL) {
    for (int i = 0; i < frame_cnt; i++) {
      if (out_frames[i] != NULL) {
        unifex_payload_release(out_frames[i]);
        unifex_free(out_frames[i]);
      }
    }
    unifex_free(out_frames);
  }

  av_packet_free(&pkt);
  return res_term;
}

UNIFEX_TERM flush(UnifexEnv *env, State *state) {
  UNIFEX_TERM res_term;
  int max_frames = 8, frame_cnt = 0;
  UnifexPayload **out_frames = NULL;

  int res = get_frames(env, NULL, &out_frames, &max_frames, &frame_cnt, state);
  switch (res) {
  case DECODER_SEND_PKT_ERROR:
    res_term = flush_result_error(env, "send_pkt");
    break;
  case DECODER_DECODE_ERROR:
    res_term = flush_result_error(env, "decode");
    break;
  default:
    res_term = flush_result_ok(env, out_frames, frame_cnt);
  }

  if (out_frames != NULL) {
    for (int i = 0; i < frame_cnt; i++) {
      if (out_frames[i] != NULL) {
        unifex_payload_release(out_frames[i]);
        unifex_free(out_frames[i]);
      }
    }
    unifex_free(out_frames);
  }

  return res_term;
}

UNIFEX_TERM get_metadata(UnifexEnv *env, State *state) {
  char *sample_format;
  switch (state->codec_ctx->sample_fmt) {
  /* This sample format should always be used (and set by the encoder),
   * but it's better to check
   */
  case AV_SAMPLE_FMT_S16:
    /* XXX: we're assuming little endianness here (this is platform-dependent) */
    sample_format = "s16le";
    break;
  default:
    return get_metadata_result_error_sample_fmt(env);
  }
  return get_metadata_result_ok(env, sample_format);
}
