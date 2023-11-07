#pragma once

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wall"
#pragma GCC diagnostic ignored "-Wextra"
#include <libavcodec/avcodec.h>
#include <libavutil/log.h>
#include <libavutil/opt.h>
#pragma GCC diagnostic pop

typedef struct _g711_encoder_state {
  AVCodecContext *codec_ctx;
} State;

#include "_generated/encoder.h"
#include "g711_common.h"

#define ENCODER_SEND_FRAME_ERROR -1
#define ENCODER_ENCODE_ERROR -2
