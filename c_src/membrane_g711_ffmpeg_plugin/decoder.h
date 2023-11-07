#pragma once

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wall"
#pragma GCC diagnostic ignored "-Wextra"
#include <libavcodec/avcodec.h>
#include <libavutil/log.h>
#include <libavutil/opt.h>
#pragma GCC diagnostic pop

typedef struct _g711_decoder_state {
  AVCodecContext *codec_ctx;
} State;

#include "_generated/decoder.h"
#include "g711_common.h"

#define DECODER_SEND_PKT_ERROR -1
#define DECODER_DECODE_ERROR -2
