package com.example.bluetooth_audio_app

import android.content.Context
import android.media.*
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import android.os.Process
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.nio.ByteBuffer
import kotlin.math.min

class AudioHandler(private val context: Context) {
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var isStreaming = false
    private var volume = 1.0f
    private var bufferSize = 512 // Default small buffer for low latency
    private var scope = CoroutineScope(Dispatchers.Default + Job())
    
    // Audio processing flags
    private var useEchoCancellation = true
    private var useNoiseSuppression = true
    private var useLowLatencyMode = true

    fun getOptimalBufferConfig(): Map<String, Int> {
        val minBuffer = AudioRecord.getMinBufferSize(
            44100,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        val optimalBuffer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val builder = AudioRecord.Builder()
            val config = AudioFormat.Builder()
                .setSampleRate(44100)
                .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .build()
            
            builder.setAudioFormat(config)
            val bufferSizeInFrames = builder.build().bufferSizeInFrames
            bufferSizeInFrames * 2 // Convert frames to bytes
        } else {
            minBuffer
        }

        return mapOf(
            "minBuffer" to minBuffer,
            "optimalBuffer" to optimalBuffer
        )
    }

    fun startAudioLoopback(result: MethodChannel.Result) {
        if (isStreaming) {
            result.success(true)
            return
        }

        try {
            // Set thread priority for audio processing
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)

            // Configure audio record
            val recordBufferSize = AudioRecord.getMinBufferSize(
                44100,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )

            audioRecord = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                AudioRecord.Builder()
                    .setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setSampleRate(44100)
                            .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .build()
                    )
                    .setBufferSizeInBytes(recordBufferSize)
                    .build()
            } else {
                AudioRecord(
                    MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                    44100,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    recordBufferSize
                )
            }

            // Configure audio track for low latency playback
            val playbackBufferSize = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                AudioTrack.getMinBufferSize(
                    44100,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT
                )
            } else {
                bufferSize * 2 // Minimum safe buffer size
            }

            audioTrack = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setSampleRate(44100)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .build()
                    )
                    .setBufferSizeInBytes(playbackBufferSize)
                    .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()
            } else {
                AudioTrack(
                    AudioManager.STREAM_VOICE_CALL,
                    44100,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    playbackBufferSize,
                    AudioTrack.MODE_STREAM
                )
            }

            // Apply audio effects if available
            if (useEchoCancellation && AcousticEchoCanceler.isAvailable()) {
                AcousticEchoCanceler.create(audioRecord!!.audioSessionId)?.enabled = true
            }
            
            if (useNoiseSuppression && NoiseSuppressor.isAvailable()) {
                NoiseSuppressor.create(audioRecord!!.audioSessionId)?.enabled = true
            }

            // Start audio processing
            audioRecord?.startRecording()
            audioTrack?.play()

            isStreaming = true
            
            // Start processing in coroutine
            scope.launch(Dispatchers.Default) {
                processAudio()
            }

            result.success(true)
        } catch (e: Exception) {
            stopAudioLoopback()
            result.error("AUDIO_ERROR", "Failed to start audio loopback", e.message)
        }
    }

    private suspend fun processAudio() {
        val buffer = ByteBuffer.allocateDirect(bufferSize)
        val shortBuffer = buffer.asShortBuffer()
        val audioData = ShortArray(bufferSize / 2)

        while (isStreaming) {
            try {
                // Read audio data
                val bytesRead = audioRecord?.read(buffer, bufferSize) ?: 0
                if (bytesRead > 0) {
                    // Apply volume
                    shortBuffer.get(audioData)
                    for (i in audioData.indices) {
                        audioData[i] = (audioData[i] * volume).toInt().toShort()
                    }
                    
                    // Write to output
                    audioTrack?.write(audioData, 0, audioData.size)
                }
                buffer.clear()
                shortBuffer.clear()
            } catch (e: Exception) {
                break
            }
        }
    }

    fun stopAudioLoopback() {
        isStreaming = false
        scope.cancel()
        
        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioTrack?.stop()
            audioTrack?.release()
        } catch (e: Exception) {
            // Handle cleanup errors
        }
        
        audioRecord = null
        audioTrack = null
        scope = CoroutineScope(Dispatchers.Default + Job())
    }

    fun setVolume(newVolume: Double) {
        volume = newVolume.toFloat()
    }

    fun enableLowLatencyMode(enable: Boolean) {
        useLowLatencyMode = enable
        // Restart audio if currently streaming
        if (isStreaming) {
            stopAudioLoopback()
            startAudioLoopback(object : MethodChannel.Result {
                override fun success(result: Any?) {}
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                override fun notImplemented() {}
            })
        }
    }
} 