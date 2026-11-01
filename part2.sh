  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double percent = _totalActiveAmols == 0 ? 0 : (_completedAmols / _totalActiveAmols);
    int percentInt = (percent * 100).toInt();
    List<AmalItem> runningAmols = _getRunningAmols();

    String hijriDate = HijriService.getHijriDate(now, widget.isBn, prayerTimes?.maghrib);
    String hijriNote = HijriService.getHijriNote(widget.isBn);
    String banglaDate = BanglaDateHelper.format(now, sunriseTime: prayerTimes?.sunrise);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBn ? 'দৈনন্দিন আমল' : 'Dainik Amal', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: widget.isBn ? 'আমল রিপোর্ট' : 'Summary Report',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SummaryScreen(isBn: widget.isBn))),
          ),
          IconButton(
            icon: const Icon(Icons.alarm),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlarmScreen(isBn: widget.isBn))),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () { _initTimes(); _loadAllData(); }),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                        Text(DateFormat('EEEE, d MMMM yyyy').format(now), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.lightBlueAccent : Colors.blue)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF143526) : Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.mosque, size: 20, color: Color(0xFF0D5C3A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(hijriDate, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C3A), fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('($hijriNote)', style: TextStyle(fontSize: 11, color: isDark ? Colors.greenAccent : Colors.green.shade800, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF332015) : Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.wb_sunny_outlined, size: 18, color: Colors.deepOrange),
                        Text(banglaDate, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.orangeAccent : Colors.deepOrange)),
                      ],
                    ),
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time_filled, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C3A), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        _currentTime,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0D5C3A),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: isDark ? const Color(0xFF1B2E24) : const Color(0xFFE8F5E9),
            elevation: 1.5,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.isBn ? 'আমলের অগ্রগতি' : 'Amal Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C3A))),
                      Text('$_completedAmols/$_totalActiveAmols ${widget.isBn ? "সম্পন্ন" : "Done"} — $percentInt%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C3A))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: percent.clamp(0.0, 1.0), minHeight: 8, borderRadius: BorderRadius.circular(5), color: const Color(0xFF0D5C3A)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.green.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.green, size: 22),
                      const SizedBox(width: 6),
                      Text(widget.isBn ? 'বর্তমান সময়ের সক্রিয় আমল (Running)' : 'Active Amals (Running)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C3A))),
                    ],
                  ),
                  const Divider(height: 16),
                  if (runningAmols.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(widget.isBn ? 'এই মুহূর্তে কোনো নির্দিষ্ট ওয়াক্তের আমল রানিং নেই।' : 'No active amals at this moment.', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    )
                  else
                    ...runningAmols.map((a) {
                      bool isDone = _amolStatus[a.id] ?? false;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(a.isFard ? Icons.star_rounded : Icons.check_circle_outline, color: a.isFard ? Colors.deepOrange : const Color(0xFF0D5C3A)),
                        title: Text(widget.isBn ? a.titleBn : a.titleEn, style: TextStyle(fontWeight: FontWeight.bold, decoration: isDone ? TextDecoration.lineThrough : null)),
                        subtitle: Text(widget.isBn ? a.categoryBn : a.categoryEn, style: const TextStyle(fontSize: 12)),
                        trailing: isDone
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(widget.isBn ? 'সম্পন্ন ' : 'Done ', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                  const Icon(Icons.lock, color: Colors.green, size: 16),
                                ],
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                                onPressed: () => _toggleAmolFromHome(a.id),
                                child: Text(widget.isBn ? 'টিক দিন' : 'Check'),
                              ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          Card(
            color: const Color(0xFF0D5C3A),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.isBn ? 'পরবর্তী নামাজ' : 'Next Prayer', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(_nextPrayerName, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(widget.isBn ? 'বাকি সময়' : 'Time Left', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(_countdown.isEmpty ? '--:--:--' : _countdown, style: const TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (prayerTimes != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.isBn ? 'নামাজের সময়' : 'Prayer Times', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF0D5C3A))),
                        InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlarmScreen(isBn: widget.isBn))),
                          child: const Row(
                            children: [
                              Icon(Icons.alarm_on, size: 18, color: Color(0xFF0D5C3A)),
                              SizedBox(width: 4),
                              Text('অ্যালার্ম', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D5C3A))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    _timeRow(widget.isBn ? 'সাহরীর শেষ সময়' : 'Suhoor Ends', prayerTimes!.fajr.subtract(const Duration(minutes: 10))),
                    _timeRow(widget.isBn ? 'ফজর' : 'Fajr', prayerTimes!.fajr),
                    _timeRow(widget.isBn ? 'সূর্যোদয়' : 'Sunrise', prayerTimes!.sunrise),
                    _timeRow(widget.isBn ? 'যোহর' : 'Dhuhr', prayerTimes!.dhuhr),
                    _timeRow(widget.isBn ? 'আসর' : 'Asr', prayerTimes!.asr),
                    _timeRow(widget.isBn ? 'সূর্যাস্ত ও মাগরিব' : 'Sunset & Maghrib', prayerTimes!.maghrib),
                    _timeRow(widget.isBn ? 'ইশা' : 'Isha', prayerTimes!.isha),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeRow(String title, DateTime time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14)),
          Text(DateFormat('hh:mm a').format(time), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
