#include "encoder.h"

void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);

  if (state->codec_ctx != NULL) {
    avcodec_free_context(&state->codec_ctx);
  }
}

UNIFEX_TERM create(UnifexEnv *env, char *sample_fmt) {
  UNIFEX_TERM res;
  State *state = unifex_alloc_state(env);
  state->codec_ctx = NULL;

  av_log_set_level(AV_LOG_QUIET);

#if (LIBAVCODEC_VERSION_MAJOR < 58)
  avcodec_register_all();
#endif
  const AVCodec *codec = avcodec_find_encoder(AV_CODEC_ID_PCM_ALAW);
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

  if (strcmp(sample_fmt, "s16le") == 0) {
    state->codec_ctx->sample_fmt = AV_SAMPLE_FMT_S16;
  } else {
    res = create_result_error(env, "sample_fmt");
    goto exit_create;
  }

  if (avcodec_open2(state->codec_ctx, codec, NULL) < 0) {
    res = create_result_error(env, "codec_open");
    goto exit_create;
  }

  res = create_result_ok(env, state);
exit_create:
  unifex_release_state(env, state);
  return res;
}

static int get_frames(UnifexEnv *env, AVFrame *frame,
                      UnifexPayload ***ret_frames, int *max_frames,
                      int *frame_cnt, State *state) {
  AVPacket *pkt = av_packet_alloc();
  UnifexPayload **frames = unifex_alloc((*max_frames) * sizeof(*frames));

  int ret = avcodec_send_frame(state->codec_ctx, frame);
  if (ret < 0) {
    ret = ENCODER_SEND_FRAME_ERROR;
    goto exit_get_frames;
  }

  ret = avcodec_receive_packet(state->codec_ctx, pkt);
  while (ret != AVERROR(EAGAIN) && ret != AVERROR_EOF) {
    if (ret < 0) {
      ret = ENCODER_ENCODE_ERROR;
      goto exit_get_frames;
    }

    if (*frame_cnt >= (*max_frames)) {
      *max_frames *= 2;
      frames = unifex_realloc(frames, (*max_frames) * sizeof(*frames));
    }

    frames[*frame_cnt] = unifex_alloc(sizeof(UnifexPayload));

    /* TODO: add shm support? */
    unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, pkt->size, frames[*frame_cnt]);
    memcpy(frames[*frame_cnt]->data, pkt->data, pkt->size);
    (*frame_cnt)++;

    ret = avcodec_receive_packet(state->codec_ctx, pkt);
  }
  ret = 0;
exit_get_frames:
  *ret_frames = frames;
  av_packet_free(&pkt);
  return ret;
}

UNIFEX_TERM encode(UnifexEnv *env, UnifexPayload *payload, State *state) {
  UNIFEX_TERM res_term;
  int res = 0;
  int max_frames = 16, frame_cnt = 0;
  UnifexPayload **out_frames = NULL;

  AVFrame *frame = av_frame_alloc();

  frame->nb_samples = payload->size / av_get_bytes_per_sample(state->codec_ctx->sample_fmt);
  frame->format = state->codec_ctx->sample_fmt;
  av_channel_layout_copy(&frame->ch_layout, &state->codec_ctx->ch_layout);

  frame->data[0] = payload->data;

  res = get_frames(env, frame, &out_frames, &max_frames, &frame_cnt, state);

  switch (res) {
  case ENCODER_SEND_FRAME_ERROR:
    res_term = encode_result_error(env, "send_frame");
    break;
  case ENCODER_ENCODE_ERROR:
    res_term = encode_result_error(env, "encode");
    break;
  default:
    res_term = encode_result_ok(env, out_frames, frame_cnt);
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

  av_frame_free(&frame);
  return res_term;
}

UNIFEX_TERM flush(UnifexEnv *env, State *state) {
  UNIFEX_TERM res_term;
  int max_frames = 8, frame_cnt = 0;
  UnifexPayload **out_frames = NULL;

  int res = get_frames(env, NULL, &out_frames, &max_frames, &frame_cnt, state);
  switch (res) {
  case ENCODER_SEND_FRAME_ERROR:
    res_term = encode_result_error(env, "send_frame");
    break;
  case ENCODER_ENCODE_ERROR:
    res_term = encode_result_error(env, "encode");
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
