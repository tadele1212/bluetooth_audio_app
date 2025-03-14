package com.example.bluetooth_audio_app

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.bluetooth_audio_app/audio"
    private lateinit var audioManager: AudioManager
    
    // Audio loopback components
    private var isAudioLoopbackRunning = AtomicBoolean(false)
    private var audioLoopbackThread: Thread? = null
    private var audioGain: Float = 1.0f
    
    // Tag for logging
    private val TAG = "HearingAidAudio"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Set up audio manager
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableBluetoothSco" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    val success = enableBluetoothSco(enable)
                    result.success(success)
                }
                "isBluetoothScoOn" -> {
                    val isOn = audioManager.isBluetoothScoOn
                    result.success(isOn)
                }
                "isBluetoothA2dpOn" -> {
                    val isOn = audioManager.isBluetoothA2dpOn
                    result.success(isOn)
                }
                "isWiredHeadsetOn" -> {
                    val isOn = audioManager.isWiredHeadsetOn
                    result.success(isOn)
                }
                "getSpeakerphoneState" -> {
                    val isOn = audioManager.isSpeakerphoneOn
                    result.success(isOn)
                }
                "setSpeakerphoneOn" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    audioManager.isSpeakerphoneOn = enable
                    result.success(true)
                }
                "getConnectedDevices" -> {
                    val devices = getConnectedAudioDevices()
                    result.success(devices)
                }
                "startAudioLoopback" -> {
                    val gain = call.argument<Double>("gain")?.toFloat() ?: 1.0f
                    audioGain = gain
                    val success = startAudioLoopback()
                    result.success(success)
                }
                "stopAudioLoopback" -> {
                    stopAudioLoopback()
                    result.success(true)
                }
                "setAudioGain" -> {
                    val gain = call.argument<Double>("gain")?.toFloat() ?: 1.0f
                    audioGain = gain
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun enableBluetoothSco(enable: Boolean): Boolean {
        return try {
            if (enable) {
                // Set audio mode to enable SCO
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                
                audioManager.startBluetoothSco()
                audioManager.isBluetoothScoOn = true
                Log.d(TAG, "BluetoothSCO started, mode=${audioManager.mode}")
            } else {
                audioManager.stopBluetoothSco()
                audioManager.isBluetoothScoOn = false
                
                // Reset audio mode
                audioManager.mode = AudioManager.MODE_NORMAL
                
                Log.d(TAG, "BluetoothSCO stopped, mode=${audioManager.mode}")
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error toggling BluetoothSCO: ${e.message}")
            false
        }
    }

    private fun getConnectedAudioDevices(): List<String> {
        val deviceList = mutableListOf<String>()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (device in devices) {
                val type = when(device.type) {
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth SCO"
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth A2DP"
                    AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Wired Headset"
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "Wired Headphones"
                    AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Built-in Speaker"
                    AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "Built-in Earpiece"
                    else -> "Other: ${device.type}"
                }
                deviceList.add("$type: ${device.productName}")
            }
        } else {
            // Fallback for older Android versions
            if (audioManager.isBluetoothScoOn) deviceList.add("Bluetooth SCO")
            if (audioManager.isBluetoothA2dpOn) deviceList.add("Bluetooth A2DP")
            if (audioManager.isWiredHeadsetOn) deviceList.add("Wired Headset")
            if (audioManager.isSpeakerphoneOn) deviceList.add("Speakerphone")
        }
        
        return deviceList
    }
    
    private fun startAudioLoopback(): Boolean {
        if (isAudioLoopbackRunning.get()) {
            Log.d(TAG, "Audio loopback already running")
            return true
        }
        
        try {
            // Request audio focus for hearing aid
            val result = audioManager.requestAudioFocus(null, 
                AudioManager.STREAM_VOICE_CALL,  // Using voice call stream for better routing
                AudioManager.AUDIOFOCUS_GAIN)
                
            if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                Log.e(TAG, "Could not get audio focus")
                return false
            }
            
            // Set volume to max for the stream
            audioManager.setStreamVolume(
                AudioManager.STREAM_VOICE_CALL,
                audioManager.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL),
                0 // No flags
            )
            
            // Enable Bluetooth SCO (this sets the mode to MODE_IN_COMMUNICATION)
            enableBluetoothSco(true)
            
            // Start the audio loopback thread
            isAudioLoopbackRunning.set(true)
            
            audioLoopbackThread = thread(start = true) {
                Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
                
                // Audio configuration - using higher sample rate for better quality
                val sampleRate = 48000
                val channelConfig = AudioFormat.CHANNEL_IN_MONO
                val audioFormat = AudioFormat.ENCODING_PCM_16BIT
                val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat) * 4 // Larger buffer
                
                Log.d(TAG, "Starting audio loopback with buffer size: $bufferSize, sample rate: $sampleRate")
                
                try {
                    // Create AudioRecord for microphone input
                    val audioRecord = AudioRecord(
                        MediaRecorder.AudioSource.VOICE_COMMUNICATION, // Better for Bluetooth headsets
                        sampleRate,
                        channelConfig,
                        audioFormat,
                        bufferSize
                    )
                    
                    // Create AudioTrack for output
                    val audioTrack = AudioTrack.Builder()
                        .setAudioAttributes(
                            android.media.AudioAttributes.Builder()
                                .setUsage(android.media.AudioAttributes.USAGE_VOICE_COMMUNICATION)
                                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                                .build()
                        )
                        .setAudioFormat(
                            AudioFormat.Builder()
                                .setEncoding(audioFormat)
                                .setSampleRate(sampleRate)
                                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                                .build()
                        )
                        .setBufferSizeInBytes(bufferSize)
                        .setTransferMode(AudioTrack.MODE_STREAM)
                        .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                        .build()
                    
                    // Start audio components
                    audioTrack.play()
                    
                    // Check if the record state is OK before proceeding
                    if (audioRecord.state != AudioRecord.STATE_INITIALIZED) {
                        throw Exception("AudioRecord not initialized, state: ${audioRecord.state}")
                    }
                    
                    audioRecord.startRecording()
                    
                    // Log active audio device
                    Log.d(TAG, "Audio loopback started, Bluetooth SCO: ${audioManager.isBluetoothScoOn}, A2DP: ${audioManager.isBluetoothA2dpOn}")
                    
                    val buffer = ShortArray(bufferSize / 2)
                    
                    // Main audio loopback loop
                    while (isAudioLoopbackRunning.get()) {
                        val bytesRead = audioRecord.read(buffer, 0, buffer.size)
                        
                        if (bytesRead > 0) {
                            // Apply volume gain
                            if (audioGain != 1.0f) {
                                for (i in 0 until bytesRead) {
                                    buffer[i] = (buffer[i] * audioGain).toInt().toShort()
                                }
                            }
                            
                            // Write to output
                            audioTrack.write(buffer, 0, bytesRead)
                        }
                    }
                    
                    // Clean up
                    Log.d(TAG, "Stopping audio loopback")
                    audioTrack.stop()
                    audioRecord.stop()
                    audioTrack.release()
                    audioRecord.release()
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Error in audio loopback: ${e.message}")
                    isAudioLoopbackRunning.set(false)
                }
            }
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start audio loopback: ${e.message}")
            isAudioLoopbackRunning.set(false)
            return false
        }
    }
    
    private fun stopAudioLoopback() {
        if (!isAudioLoopbackRunning.get()) {
            return
        }
        
        isAudioLoopbackRunning.set(false)
        
        try {
            audioLoopbackThread?.join(1000)
            audioLoopbackThread = null
            
            // Disable Bluetooth SCO (this also resets audio mode)
            enableBluetoothSco(false)
            
            // Abandon audio focus
            audioManager.abandonAudioFocus(null)
            
            Log.d(TAG, "Audio loopback stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping audio loopback: ${e.message}")
        }
    }
    
    override fun onDestroy() {
        stopAudioLoopback()
        super.onDestroy()
    }
}
