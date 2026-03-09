import React, {useEffect, useState, useCallback} from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import api from '../api/lifterlms';

const CMEScreen: React.FC = () => {
  const [summary, setSummary] = useState<any>(null);
  const [credits, setCredits] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  const loadData = useCallback(async () => {
    setIsLoading(true);
    try {
      const [summaryRes, creditsRes] = await Promise.all([
        api.getCmeSummary().catch(() => null),
        api.getCmeCredits().catch(() => []),
      ]);
      setSummary(summaryRes);
      setCredits(Array.isArray(creditsRes) ? creditsRes : []);
    } catch (_) {}
    setIsLoading(false);
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#4FC3F7" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>CME Credits</Text>

      {/* Summary cards */}
      {summary && (
        <View style={styles.summaryRow}>
          <View style={styles.summaryCard}>
            <Text style={styles.summaryValue}>
              {summary.total_credits || 0}
            </Text>
            <Text style={styles.summaryLabel}>Total Credits</Text>
          </View>
          <View style={styles.summaryCard}>
            <Text style={styles.summaryValue}>
              {summary.courses_completed || 0}
            </Text>
            <Text style={styles.summaryLabel}>Courses Completed</Text>
          </View>
          <View style={styles.summaryCard}>
            <Text style={styles.summaryValue}>
              {summary.expiring_soon || 0}
            </Text>
            <Text style={styles.summaryLabel}>Expiring Soon</Text>
          </View>
        </View>
      )}

      {/* Credit history */}
      <Text style={styles.sectionTitle}>Credit History</Text>
      <ScrollView contentContainerStyle={styles.creditList}>
        {credits.map((credit: any, i: number) => (
          <View key={i} style={styles.creditRow}>
            <View style={styles.creditInfo}>
              <Text style={styles.creditTitle}>
                {credit.activity_title || credit.course_title || 'Course'}
              </Text>
              <Text style={styles.creditType}>
                {(credit.credit_type || '').replace(/_/g, ' ').toUpperCase()}
              </Text>
            </View>
            <View style={styles.creditRight}>
              <Text style={styles.creditHours}>
                {credit.credit_hours || 0} hrs
              </Text>
              <Text style={styles.creditDate}>
                {credit.date_awarded || credit.date || ''}
              </Text>
            </View>
          </View>
        ))}
        {credits.length === 0 && (
          <Text style={styles.empty}>No CME credits yet</Text>
        )}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
    paddingHorizontal: 60,
    paddingTop: 40,
  },
  loadingContainer: {
    flex: 1,
    backgroundColor: '#0a0a0a',
    justifyContent: 'center',
    alignItems: 'center',
  },
  title: {
    fontSize: 32,
    fontWeight: '800',
    color: '#FFFFFF',
    marginBottom: 30,
  },
  summaryRow: {
    flexDirection: 'row',
    gap: 20,
    marginBottom: 40,
  },
  summaryCard: {
    backgroundColor: '#1e1e1e',
    borderRadius: 16,
    padding: 30,
    flex: 1,
    alignItems: 'center',
  },
  summaryValue: {
    fontSize: 42,
    fontWeight: '800',
    color: '#4FC3F7',
  },
  summaryLabel: {
    fontSize: 16,
    color: '#999',
    marginTop: 8,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '700',
    color: '#FFFFFF',
    marginBottom: 16,
  },
  creditList: {
    paddingBottom: 60,
  },
  creditRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    backgroundColor: '#1e1e1e',
    padding: 20,
    borderRadius: 10,
    marginBottom: 8,
  },
  creditInfo: {
    flex: 1,
  },
  creditTitle: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
  },
  creditType: {
    color: '#4FC3F7',
    fontSize: 14,
    marginTop: 4,
  },
  creditRight: {
    alignItems: 'flex-end',
  },
  creditHours: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: '700',
  },
  creditDate: {
    color: '#999',
    fontSize: 14,
    marginTop: 4,
  },
  empty: {
    color: '#666',
    fontSize: 18,
    fontStyle: 'italic',
    marginTop: 20,
  },
});

export default CMEScreen;
